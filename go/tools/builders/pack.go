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

// pack copies an .a file and appends a list of .o files to the copy using
// go tool pack. It is invoked by the Go rules as an action.
//
// pack can also append .o files contained in a static library passed in
// with the -arc option. That archive may be in BSD or SysV / GNU format.
// pack has a primitive parser for these formats, since cmd/pack can't
// handle them, and ar may not be available (cpp.ar_executable is libtool
// on darwin).
package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

func run(args []string) error {
	flags := flag.NewFlagSet("pack", flag.ContinueOnError)
	goenv := envFlags(flags)
	inArchive := flags.String("in", "", "Path to input archive")
	outArchive := flags.String("out", "", "Path to output archive")
	objects := multiFlag{}
	flags.Var(&objects, "obj", "Object to append (may be repeated)")
	archive := flags.String("arc", "", "Archive to append (at most one)")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.update(); err != nil {
		return err
	}

	if err := copyFile(*inArchive, *outArchive); err != nil {
		return err
	}

	if *archive != "" {
		archiveObjects, err := extractFiles(*archive)
		if err != nil {
			return err
		}
		objects = append(objects, archiveObjects...)
	}

	return appendFiles(goenv, *outArchive, objects)
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func copyFile(inPath, outPath string) error {
	inFile, err := os.Open(inPath)
	if err != nil {
		return err
	}
	defer inFile.Close()
	outFile, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer outFile.Close()
	_, err = io.Copy(outFile, inFile)
	return err
}

const (
	// arHeader appears at the beginning of archives created by "ar" and
	// "go tool pack" on all platforms.
	arHeader = "!<arch>\n"

	// entryLength is the size in bytes of the metadata preceding each file
	// in an archive.
	entryLength = 60
)

func extractFiles(archive string) (files []string, err error) {
	f, err := os.Open(archive)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	r := bufio.NewReader(f)

	header := make([]byte, len(arHeader))
	if _, err := io.ReadFull(r, header); err != nil || string(header) != arHeader {
		return nil, fmt.Errorf("%s: bad header", archive)
	}

	var nameData []byte
	names := make(map[string]bool)
	for {
		name, size, err := readMetadata(r, &nameData)
		if err == io.EOF {
			return files, nil
		}
		if err != nil {
			return nil, err
		}
		if !isObjectFile(name) {
			if err := skipFile(r, size); err != nil {
				return nil, err
			}
			continue
		}
		name = simpleName(name, names)
		names[name] = true
		if err := extractFile(r, name, size); err != nil {
			return nil, err
		}
		files = append(files, name)
	}
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
// such a name, simpleName will truncate the given name to 15 characters
func simpleName(name string, names map[string]bool) string {
	if len(name) < 16 && !names[name] {
		return name
	}
	var stem, ext string
	if i := strings.LastIndexByte(name, '.'); i < 0 || len(name)-i >= 10 {
		stem = name
	} else {
		stem = name[:i]
		ext = name[i:]
	}
	for n := 0; n < len(names); n++ {
		ns := strconv.Itoa(n)
		stemLen := 15 - len(ext) - len(ns)
		if stemLen > len(stem) {
			stemLen = len(stem)
		}
		candidate := stem[:stemLen] + ns + ext
		if !names[candidate] {
			return candidate
		}
	}
	return name[:15]
}

func appendFiles(goenv *GoEnv, archive string, files []string) error {
	args := append([]string{"tool", "pack", "r", archive}, files...)
	env := os.Environ()
	env = append(env, goenv.Env()...)
	cmd := exec.Command(goenv.Go, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	return cmd.Run()
}
