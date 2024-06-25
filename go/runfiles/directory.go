// Copyright 2020, 2021, 2021 Google LLC
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
	"errors"
	"io/fs"
	"os"
	"path/filepath"
)

// Directory specifies the location of the runfiles directory.  You can pass
// this as an option to New.  If unset or empty, use the value of the
// environmental variable RUNFILES_DIR.
type Directory string

func (d Directory) new(sourceRepo SourceRepo) (*Runfiles, error) {
	r := &Runfiles{
		impl: d,
		env: []string{
			directoryVar + "=" + string(d),
			legacyDirectoryVar + "=" + string(d),
		},
		sourceRepo: string(sourceRepo),
	}
	err := r.loadRepoMapping()
	return r, err
}

func (d Directory) path(s string) (string, error) {
	return filepath.Join(string(d), filepath.FromSlash(s)), nil
}

func (d Directory) open(name string) (fs.File, error) {
	f, err := os.DirFS(string(d)).Open(name)
	if err != nil {
		return nil, err
	}
	return &resolvedFile{f.(*os.File), func(child string) (fs.FileInfo, error) {
		path := filepath.Join(string(d), filepath.FromSlash(name), child)
		target, err := os.Readlink(path)
		if err != nil {
			if errors.Is(err, os.ErrInvalid) {
				target = path
			} else {
				return nil, err
			}
		}
		return os.Lstat(target)
	}}, nil
}

type resolvedFile struct {
	fs.ReadDirFile
	lstatChildAfterReadlink func(string) (fs.FileInfo, error)
}

func (f *resolvedFile) ReadDir(n int) ([]fs.DirEntry, error) {
	entries, err := f.ReadDirFile.ReadDir(n)
	if err != nil {
		return nil, err
	}
	for i, entry := range entries {
		if entry.Type()&fs.ModeSymlink != 0 {
			info, err := f.lstatChildAfterReadlink(entry.Name())
			if err != nil {
				return nil, err
			}
			entries[i] = renamedDirEntry{fs.FileInfoToDirEntry(info), entry.Name()}
		}
	}
	return entries, nil
}
