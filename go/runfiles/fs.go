// Copyright 2021, 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package runfiles

import (
	"io"
	"io/fs"
	"sort"
	"strings"
	"time"
)

// Open implements fs.FS for a Runfiles instance.
//
// Rlocation-style paths are supported with both apparent and canonical repo
// names. The root directory of the filesystem (".") only lists the apparent
// repo names that are visible to the current source repo
// (with --enable_bzlmod).
func (r *Runfiles) Open(name string) (fs.File, error) {
	if !fs.ValidPath(name) {
		return nil, &fs.PathError{Op: "open", Path: name, Err: fs.ErrInvalid}
	}
	if name == "." {
		return &rootDir{".", r, nil}, nil
	}
	split := strings.SplitN(name, "/", 2)
	key := repoMappingKey{r.sourceRepo, split[0]}
	targetRepoDirectory, exists := r.repoMapping[key]
	if !exists {
		// Either name uses a canonical repo name or refers to a root symlink.
		// In both cases, we can just open the file directly.
		return r.impl.open(name)
	}
	mappedPath := targetRepoDirectory
	if len(split) > 1 {
		mappedPath += "/" + split[1]
	}
	f, err := r.impl.open(mappedPath)
	if err != nil {
		return nil, err
	}
	if len(split) > 1 {
		return f, nil
	}
	// Return a special file for a repo dir that knows its apparent name.
	return &repoDirFile{f.(fs.ReadDirFile), split[0]}, nil
}

type rootDir struct {
	dirFile
	rf      *Runfiles
	entries []fs.DirEntry
}

func (r *rootDir) ReadDir(n int) ([]fs.DirEntry, error) {
	if err := r.initEntries(); err != nil {
		return nil, err
	}
	if n > 0 && len(r.entries) == 0 {
		return nil, io.EOF
	}
	if n <= 0 || n > len(r.entries) {
		n = len(r.entries)
	}
	entries := r.entries[:n]
	r.entries = r.entries[n:]
	return entries, nil
}

func (r *rootDir) initEntries() error {
	if r.entries != nil {
		return nil
	}
	// The entries of the root dir should be the apparent names of the repos
	// visible to the main repo (plus root symlinks). We thus need to read
	// the real entries and then transform and filter them.
	canonicalToApparentName := make(map[string]string)
	allCanonicalNames := make(map[string]struct{})
	for k, v := range r.rf.repoMapping {
		allCanonicalNames[v] = struct{}{}
		if k.sourceRepo == r.rf.sourceRepo {
			canonicalToApparentName[v] = k.targetRepoApparentName
		}
	}
	rootFile, err := r.rf.impl.open(".")
	if err != nil {
		return err
	}
	rootDirFile := rootFile.(fs.ReadDirFile)
	realEntries, err := rootDirFile.ReadDir(-1)
	if err != nil {
		return err
	}
	for _, e := range realEntries {
		if apparent, ok := canonicalToApparentName[e.Name()]; ok && e.IsDir() {
			// A repo directory that is visible to the current source repo is materialized
			// under its apparent name.
			r.entries = append(r.entries, repoDirEntry{e, apparent})
		} else if _, ok := allCanonicalNames[e.Name()]; ok && e.IsDir() {
			// Skip repo directory that isn't visible to the current source repo.
		} else {
			// This is either a root symlink or Bzlmod is not enabled. In the latter case,
			// allCanonicalNames only contains the name of the main repo. Since without
			// Bzlmod there is no strict repo visibility, we materialize all directories.
			r.entries = append(r.entries, e)
		}
	}
	sort.Slice(r.entries, func(i, j int) bool {
		return r.entries[i].Name() < r.entries[j].Name()
	})
	return nil
}

type repoDirFile struct {
	fs.ReadDirFile
	name string
}

func (r repoDirFile) Stat() (fs.FileInfo, error) {
	info, err := r.ReadDirFile.Stat()
	if err != nil {
		return nil, err
	}
	return repoDirFileInfo{info, r.name}, nil
}

type repoDirEntry struct {
	fs.DirEntry
	name string
}

func (r repoDirEntry) Name() string { return r.name }
func (r repoDirEntry) Info() (fs.FileInfo, error) {
	info, err := r.DirEntry.Info()
	if err != nil {
		return nil, err
	}
	return repoDirFileInfo{info, r.name}, nil
}

type repoDirFileInfo struct {
	fs.FileInfo
	name string
}

func (r repoDirFileInfo) Name() string { return r.name }

type emptyFile string

func (f emptyFile) Stat() (fs.FileInfo, error) { return emptyFileInfo(f), nil }
func (f emptyFile) Read([]byte) (int, error)   { return 0, io.EOF }
func (emptyFile) Close() error                 { return nil }

type emptyFileInfo string

func (i emptyFileInfo) Name() string     { return string(i) }
func (emptyFileInfo) Size() int64        { return 0 }
func (emptyFileInfo) Mode() fs.FileMode  { return 0444 }
func (emptyFileInfo) ModTime() time.Time { return time.Time{} }
func (emptyFileInfo) IsDir() bool        { return false }
func (emptyFileInfo) Sys() interface{}   { return nil }
