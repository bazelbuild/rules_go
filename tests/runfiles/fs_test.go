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
	"testing"
	"testing/fstest"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func TestFS_native(t *testing.T) {
	r, err := runfiles.New()
	if err != nil {
		t.Fatal(err)
	}
	testFS(t, r)
}

func TestFS_manifest(t *testing.T) {
	// Turn our own runfiles (whatever the form) into a valid manifest file.
	tempdir := t.TempDir()
	manifest := filepath.Join(tempdir, "manifest")
	manifestFile, err := os.Create(manifest)
	if err != nil {
		t.Fatal(err)
	}
	for _, source := range []string{
		"_main/tests/runfiles/runfiles_test_/runfiles_test",
		"_main/tests/runfiles/test.txt",
		"_main/tests/runfiles/testprog/testprog_/testprog",
		"_repo_mapping",
		"bazel_tools/tools/bash/runfiles/runfiles.bash",
	} {
		target, err := runfiles.Rlocation(source)
		if err != nil {
			t.Fatal(err)
		}
		_, err = manifestFile.WriteString(source + " " + target + "\n")
		if err != nil {
			t.Fatal(err)
		}
	}
	if err = manifestFile.Close(); err != nil {
		t.Fatal(err)
	}

	fsys, err := runfiles.New(runfiles.ManifestFile(manifest))
	if err != nil {
		t.Fatal(err)
	}

	testFS(t, fsys)
}

func testFS(t *testing.T, r *runfiles.Runfiles) {
	// Ensure that the Runfiles object implements FS interfaces.
	var _ fs.FS = r
	var _ fs.StatFS = r
	var _ fs.ReadFileFS = r

	if err := fstest.TestFS(
		r,
		"io_bazel_rules_go/tests/runfiles/test.txt",
		"io_bazel_rules_go/tests/runfiles/testprog/testprog_/testprog",
		"bazel_tools/tools/bash/runfiles/runfiles.bash",
	); err != nil {
		t.Error(err)
	}

	// Canonical repo names are not returned by readdir, but can still be accessed.
	f, err := r.Open("_main/tests/runfiles/test.txt")
	if err != nil {
		t.Fatal(err)
	}
	info, err := f.Stat()
	if err != nil {
		t.Fatal(err)
	}
	if info.Name() != "test.txt" {
		t.Errorf("Name: got %q, want %q", info.Name(), "test.txt")
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
