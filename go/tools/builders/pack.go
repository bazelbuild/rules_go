// Copyright 2017 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

func copyFile(inPath, outPath string) error {
	inFile, err := os.Open(inPath)
	if err != nil {
		return err
	}
	defer inFile.Close()
	outFile, err := os.OpenFile(outPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0666)
	if err != nil {
		return err
	}
	defer outFile.Close()
	_, err = io.Copy(outFile, inFile)
	return err
}

func linkFile(inPath, outPath string) error {
	inPath, err := filepath.Abs(inPath)
	if err != nil {
		return err
	}
	return os.Symlink(inPath, outPath)
}

func copyOrLinkFile(inPath, outPath string) error {
	if runtime.GOOS == "windows" {
		return copyFile(inPath, outPath)
	} else {
		return linkFile(inPath, outPath)
	}
}

const (
	// arHeader appears at the beginning of archives created by "ar" and
	// "go tool pack" on all platforms.
	arHeader = "!<arch>\n"

	// entryLength is the size in bytes of the metadata preceding each file
	// in an archive.
	entryLength = 60

	// pkgDef is the name of the export data file within an archive
	pkgDef = "__.PKGDEF"

	// nogoFact is the name of the nogo fact file
	nogoFact = "nogo.out"
)

var zeroBytes = []byte("0                    ")

type bufioReaderWithCloser struct {
	// bufio.Reader is needed to skip bytes in archives
	*bufio.Reader
	io.Closer
}

func extractFiles(archive, dir string, names map[string]struct{}) (files []string, err error) {
	rc, err := openArchive(archive)
	if err != nil {
		return nil, err
	}
	defer rc.Close()

	var nameData []byte
	bufReader := rc.Reader
	for {
		name, size, err := readMetadata(bufReader, &nameData)
		if err == io.EOF {
			return files, nil
		}
		if err != nil {
			return nil, err
		}
		if !isObjectFile(name) {
			if err := skipFile(bufReader, size); err != nil {
				return nil, err
			}
			continue
		}
		name, err = simpleName(name, names)
		if err != nil {
			return nil, err
		}
		name = filepath.Join(dir, name)
		if err := extractFile(bufReader, name, size); err != nil {
			return nil, err
		}
		files = append(files, name)
	}
}

func openArchive(archive string) (bufioReaderWithCloser, error) {
	f, err := os.Open(archive)
	if err != nil {
		return bufioReaderWithCloser{}, err
	}
	r := bufio.NewReader(f)
	header := make([]byte, len(arHeader))
	if _, err := io.ReadFull(r, header); err != nil || string(header) != arHeader {
		f.Close()
		return bufioReaderWithCloser{}, fmt.Errorf("%s: bad header", archive)
	}
	return bufioReaderWithCloser{r, f}, nil
}

// readMetadata reads the relevant fields of an entry. Before calling,
// r must be positioned at the beginning of an entry. Afterward, r will
// be positioned at the beginning of the file data. io.EOF is returned if
// there are no more files in the archive.
//
// Both BSD and GNU / SysV naming conventions are supported.
func readMetadata(r *bufio.Reader, nameData *[]byte) (name string, size int64, err error) {
retry:
	// Each file is preceded by a 60-byte header that contains its metadata.
	// We only care about two fields, name and size. Other fields (mtime,
	// owner, group, mode) are ignored because they don't affect compilation.
	var entry [entryLength]byte
	if _, err := io.ReadFull(r, entry[:]); err != nil {
		return "", 0, err
	}

	sizeField := strings.TrimSpace(string(entry[48:58]))
	size, err = strconv.ParseInt(sizeField, 10, 64)
	if err != nil {
		return "", 0, err
	}

	nameField := strings.TrimRight(string(entry[:16]), " ")
	switch {
	case strings.HasPrefix(nameField, "#1/"):
		// BSD-style name. The number of bytes in the name is written here in
		// ASCII, right-padded with spaces. The actual name is stored at the
		// beginning of the file data, left-padded with NUL bytes.
		nameField = nameField[len("#1/"):]
		nameLen, err := strconv.ParseInt(nameField, 10, 64)
		if err != nil {
			return "", 0, err
		}
		nameBuf := make([]byte, nameLen)
		if _, err := io.ReadFull(r, nameBuf); err != nil {
			return "", 0, err
		}
		name = strings.TrimRight(string(nameBuf), "\x00")
		size -= nameLen

	case nameField == "//":
		// GNU / SysV-style name data. This is a fake file that contains names
		// for files with long names. We read this into nameData, then read
		// the next entry.
		*nameData = make([]byte, size)
		if _, err := io.ReadFull(r, *nameData); err != nil {
			return "", 0, err
		}
		if size%2 != 0 {
			// Files are aligned at 2-byte offsets. Discard the padding byte if the
			// size was odd.
			if _, err := r.ReadByte(); err != nil {
				return "", 0, err
			}
		}
		goto retry

	case nameField == "/":
		// GNU / SysV-style symbol lookup table. Skip.
		if err := skipFile(r, size); err != nil {
			return "", 0, err
		}
		goto retry

	case strings.HasPrefix(nameField, "/"):
		// GNU / SysV-style long file name. The number that follows the slash is
		// an offset into the name data that should have been read earlier.
		// The file name ends with a slash.
		nameField = nameField[1:]
		nameOffset, err := strconv.Atoi(nameField)
		if err != nil {
			return "", 0, err
		}
		if nameData == nil || nameOffset < 0 || nameOffset >= len(*nameData) {
			return "", 0, fmt.Errorf("invalid name length: %d", nameOffset)
		}
		i := bytes.IndexByte((*nameData)[nameOffset:], '/')
		if i < 0 {
			return "", 0, errors.New("file name does not end with '/'")
		}
		name = string((*nameData)[nameOffset : nameOffset+i])

	case strings.HasSuffix(nameField, "/"):
		// GNU / SysV-style short file name.
		name = nameField[:len(nameField)-1]

	default:
		// Common format name.
		name = nameField
	}

	return name, size, err
}

// extractFile reads size bytes from r and writes them to a new file, name.
func extractFile(r *bufio.Reader, name string, size int64) error {
	w, err := os.Create(name)
	if err != nil {
		return err
	}
	defer w.Close()
	_, err = io.CopyN(w, r, size)
	if err != nil {
		return err
	}
	if size%2 != 0 {
		// Files are aligned at 2-byte offsets. Discard the padding byte if the
		// size was odd.
		if _, err := r.ReadByte(); err != nil {
			return err
		}
	}
	return nil
}

func skipFile(r *bufio.Reader, size int64) error {
	if size%2 != 0 {
		// Files are aligned at 2-byte offsets. Discard the padding byte if the
		// size was odd.
		size += 1
	}
	_, err := r.Discard(int(size))
	return err
}

func isObjectFile(name string) bool {
	return strings.HasSuffix(name, ".o")
}

// simpleName returns a file name which is at most 15 characters
// and doesn't conflict with other names. If it is not possible to choose
// such a name, simpleName will truncate the given name to 15 characters.
// The original file extension will be preserved.
func simpleName(name string, names map[string]struct{}) (string, error) {
	if _, ok := names[name]; !ok && len(name) < 16 {
		names[name] = struct{}{}
		return name, nil
	}
	var stem, ext string
	if i := strings.LastIndexByte(name, '.'); i < 0 {
		stem = name
	} else {
		stem = strings.Replace(name[:i], ".", "_", -1)
		ext = name[i:]
	}
	for n := 0; n < len(names)+1; n++ {
		ns := strconv.Itoa(n)
		stemLen := 15 - len(ext) - len(ns)
		if stemLen < 0 {
			break
		}
		if stemLen > len(stem) {
			stemLen = len(stem)
		}
		candidate := stem[:stemLen] + ns + ext
		if _, ok := names[candidate]; !ok {
			names[candidate] = struct{}{}
			return candidate, nil
		}
	}
	return "", fmt.Errorf("cannot shorten file name: %q", name)
}

func appendFiles(goenv *env, archive string, files []string) error {
	archive = abs(archive) // required for long filenames on Windows.

	// Create an empty archive if one doesn't already exist.
	// In Go 1.16, 'go tool pack r' reports an error if the archive doesn't exist.
	// 'go tool pack c' copies export data in addition to creating the archive,
	// so we don't want to use that directly.
	_, err := os.Stat(archive)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if os.IsNotExist(err) {
		if err := ioutil.WriteFile(archive, []byte(arHeader), 0666); err != nil {
			return err
		}
	}

	// Append files to the archive.
	// TODO(jayconrod): copy cmd/internal/archive and use that instead of
	// shelling out to cmd/pack.
	args := goenv.goTool("pack", "r", archive)
	args = append(args, files...)
	return goenv.runCommand(args)
}

type readWithCloser struct {
	io.Reader
	io.Closer
}

func readFileInArchive(fileName, archive string) (io.ReadCloser, error) {
	rc, err := openArchive(archive)
	if err != nil {
		return nil, err
	}
	var nameData []byte
	bufReader := rc.Reader
	for err == nil {
		// avoid shadowing err in the loop it can be returned correctly in the end
		var (
			name string
			size int64
		)
		name, size, err = readMetadata(bufReader, &nameData)
		if err != nil {
			break
		}
		if name == fileName {
			return readWithCloser{
				Reader: io.LimitReader(rc, size),
				Closer: rc,
			}, nil
		}
		err = skipFile(bufReader, size)
	}
	if err == io.EOF {
		err = os.ErrNotExist
	}
	rc.Close()
	return nil, err
}

func extractFileFromArchive(archive, dir, name string) (err error) {
	archiveReader, err := readFileInArchive(name, archive)
	if err != nil {
		return fmt.Errorf("error reading %s from %s: %v", name, archive, err)
	}
	defer func() {
		e := archiveReader.Close()
		if e != nil && err == nil {
			err = fmt.Errorf("error closing %q: %v", archive, e)
		}
	}()
	outPath := filepath.Join(dir, pkgDef)
	outFile, err := os.Create(outPath)
	if err != nil {
		return fmt.Errorf("error creating %s: %v", outPath, err)
	}
	defer func() {
		e := outFile.Close()
		if e != nil && err == nil {
			err = fmt.Errorf("error closing %q: %v", outPath, e)
		}
	}()
	if size, err := io.Copy(outFile, archiveReader); err != nil {
		return fmt.Errorf("error writing %s: %v", outPath, err)
	} else if size == 0 {
		return fmt.Errorf("%s is empty in %s", name, archive)
	}
	return err
}
