// Copyright 2021 Google LLC
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

//go:build go1.16
// +build go1.16

package runfiles_test

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"testing/fstest"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func TestFS(t *testing.T) {
	fsys, err := runfiles.New()
	if err != nil {
		t.Fatal(err)
	}

	// Ensure that the Runfiles object implements FS interfaces.
	var _ fs.FS = fsys
	var _ fs.StatFS = fsys
	var _ fs.ReadFileFS = fsys

	if runtime.GOOS == "windows" {
		// Currently the result of
		//
		//  fsys.Rlocation("io_bazel_rules_go/go/runfiles/test.txt")
		//  fsys.Rlocation("bazel_tools/tools/bash/runfiles/runfiles.bash")
		//  fsys.Rlocation("io_bazel_rules_go/go/runfiles/testprog/testprog")
		//
		// would be a full path like these
		//
		//  C:\b\bk-windows-1z0z\bazel\rules-go-golang\go\tools\bazel\runfiles\test.txt
		//  C:\b\zslxztin\external\bazel_tools\tools\bash\runfiles\runfiles.bash
		//  C:\b\pm4ep4b2\execroot\io_bazel_rules_go\bazel-out\x64_windows-fastbuild\bin\go\tools\bazel\runfiles\testprog\testprog
		//
		// Which does not follow any particular patter / rules.
		// This makes it very hard to define what we are looking for on Windows.
		// So let's skip this for now.
		return
	}

	expected1 := "io_bazel_rules_go/tests/runfiles/test.txt"
	expected2 := "io_bazel_rules_go/tests/runfiles/testprog/testprog_/testprog"
	expected3 := "bazel_tools/tools/bash/runfiles/runfiles.bash"
	if err := fstest.TestFS(fsys, expected1, expected2, expected3); err != nil {
		t.Error(err)
	}
}

func TestFS_empty(t *testing.T) {
	dir := t.TempDir()
	manifest := filepath.Join(dir, "manifest")
	if err := os.WriteFile(manifest, []byte("__init__.py \n"), 0o600); err != nil {
		t.Fatal(err)
	}
	fsys, err := runfiles.New(runfiles.ManifestFile(manifest), runfiles.ProgramName("/invalid"), runfiles.Directory("/invalid"))
	if err != nil {
		t.Fatal(err)
	}
	t.Run("Open", func(t *testing.T) {
		fd, err := fsys.Open("__init__.py")
		if err != nil {
			t.Fatal(err)
		}
		defer fd.Close()
		got, err := io.ReadAll(fd)
		if err != nil {
			t.Error(err)
		}
		if len(got) != 0 {
			t.Errorf("got nonempty contents: %q", got)
		}
	})
	t.Run("Stat", func(t *testing.T) {
		got, err := fsys.Stat("__init__.py")
		if err != nil {
			t.Fatal(err)
		}
		if got.Name() != "__init__.py" {
			t.Errorf("Name: got %q, want %q", got.Name(), "__init__.py")
		}
		if got.Size() != 0 {
			t.Errorf("Size: got %d, want %d", got.Size(), 0)
		}
		if !got.Mode().IsRegular() {
			t.Errorf("IsRegular: got %v, want %v", got.Mode().IsRegular(), true)
		}
		if got.IsDir() {
			t.Errorf("IsDir: got %v, want %v", got.IsDir(), false)
		}
	})
	t.Run("ReadFile", func(t *testing.T) {
		got, err := fsys.ReadFile("__init__.py")
		if err != nil {
			t.Error(err)
		}
		if len(got) != 0 {
			t.Errorf("got nonempty contents: %q", got)
		}
	})
}
