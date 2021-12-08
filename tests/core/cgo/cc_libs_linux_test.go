// Copyright 2018 The Bazel Authors. All rights reserved.
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

package cc_libs_test

import (
	"debug/elf"
	"path"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

func TestBinaries(t *testing.T) {
	for _, test := range []struct {
		shortPath string
		wantLibs  map[string]bool
	}{
		{
			shortPath: "tests/core/cgo/pure_bin",
			wantLibs:  map[string]bool{"libc": false, "libstdc++": false},
		}, {
			shortPath: "tests/core/cgo/c_srcs_bin",
			wantLibs:  map[string]bool{"libc": true, "libstdc++": false},
		}, {
			shortPath: "tests/core/cgo/cc_srcs_bin",
			wantLibs:  map[string]bool{"libc": true, "libstdc++": true},
		}, {
			shortPath: "tests/core/cgo/cc_deps_bin",
			wantLibs:  map[string]bool{"libc": true, "libstdc++": true},
		},
	} {
		t.Run(path.Base(test.shortPath), func(t *testing.T) {
			libs, err := listLibs(test.shortPath)
			if err != nil {
				t.Fatal(err)
			}
			haveLibs := make(map[string]bool)
			for _, lib := range libs {
				haveLibs[lib] = true
			}
			for haveLib := range haveLibs {
				if wantLib, ok := test.wantLibs[haveLib]; ok && !wantLib {
					t.Errorf("unexpected dependency on library %q", haveLib)
				}
			}
			for wantLib, want := range test.wantLibs {
				if want && !haveLibs[wantLib] {
					t.Errorf("wanted dependency on library %q", wantLib)
				}
			}

			verifyNoCachePaths(t, test.shortPath)
		})
	}
}

func listLibs(shortPath string) ([]string, error) {
	binPath, err := bazel.Runfile(shortPath)
	if err != nil {
		return nil, err
	}
	f, err := elf.Open(binPath)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	libs, err := f.ImportedLibraries()
	if err != nil {
		return nil, err
	}
	for i := range libs {
		if pos := strings.LastIndexByte(libs[i], '/'); pos >= 0 {
			libs[i] = libs[i][pos+1:]
		}
		if pos := strings.IndexByte(libs[i], '.'); pos >= 0 {
			libs[i] = libs[i][:pos]
		}
	}
	return libs, nil
}
