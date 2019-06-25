// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package bazel

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// makeAndEnterTempdir creates a temporary directory and chdirs into it.
func makeAndEnterTempdir() (func(), error) {
	oldCwd, err := os.Getwd()
	if err != nil {
		return nil, fmt.Errorf("cannot get path to current directory: %v", err)
	}

	tempDir, err := ioutil.TempDir("", "test")
	if err != nil {
		return nil, fmt.Errorf("failed to create temporary directory: %v", err)
	}

	err = os.Chdir(tempDir)
	if err != nil {
		os.RemoveAll(tempDir)
		return nil, fmt.Errorf("cannot enter temporary directory %s: %v", tempDir, err)
	}

	cleanup := func() {
		defer os.RemoveAll(tempDir)
		defer os.Chdir(oldCwd)
	}
	return cleanup, nil
}

// createPaths creates a collection of paths for testing purposes.  Paths can end with a /, in
// which case a directory is created; or they can end with a *, in which case an executable file
// is created.  (This matches the nomenclature of "ls -F".)
func createPaths(paths []string) error {
	for _, path := range paths {
		if strings.HasSuffix(path, "/") {
			if err := os.MkdirAll(path, 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %v", path, err)
			}
		} else {
			mode := os.FileMode(0644)
			if strings.HasSuffix(path, "*") {
				path = path[0 : len(path)-1]
				mode |= 0111
			}
			if err := ioutil.WriteFile(path, []byte{}, mode); err != nil {
				return fmt.Errorf("failed to create file %s with mode %v: %v", path, mode, err)
			}
		}
	}
	return nil
}

func TestRunfile(t *testing.T) {
	file := "go/tools/bazel/README.md"
	runfile, err := Runfile(file)
	if err != nil {
		t.Errorf("When reading file %s got error %s", file, err)
	}

	// Check that the file actually exist
	if _, err := os.Stat(runfile); err != nil {
		t.Errorf("File found by runfile doesn't exist")
	}
}

func TestRunfilesPath(t *testing.T) {
	path, err := RunfilesPath()
	if err != nil {
		t.Errorf("Error finding runfiles path: %s", err)
	}

	if path == "" {
		t.Errorf("Runfiles path is empty: %s", path)
	}
}

func TestNewTmpDir(t *testing.T) {
	//prefix := "new/temp/dir"
	prefix := "demodir"
	tmpdir, err := NewTmpDir(prefix)
	if err != nil {
		t.Errorf("When creating temp dir %s got error %s", prefix, err)
	}

	// Check that the tempdir actually exist
	if _, err := os.Stat(tmpdir); err != nil {
		t.Errorf("New tempdir (%s) not created. Got error %s", tmpdir, err)
	}
}

func TestTestTmpDir(t *testing.T) {
	if TestTmpDir() == "" {
		t.Errorf("TestTmpDir (TEST_TMPDIR) was left empty")
	}
}

func TestTestWorkspace(t *testing.T) {
	workspace, err := TestWorkspace()

	if workspace == "" {
		t.Errorf("Workspace is left empty")
	}

	if err != nil {
		t.Errorf("Unable to get workspace with error %s", err)
	}
}

func TestFindRunfiles(t *testing.T) {
	testData := []struct {
		name string

		pathsToCreate []string
		wantRunfiles  string
		wantOk        bool
	}{
		{
			"NoFiles",
			[]string{},
			"",
			false,
		},
		{
			"CurrentDirectory",
			[]string{
				"data-file",
			},
			".",
			true,
		},
		{
			"BazelBinNoConfigurationInPath",
			[]string{
				"bazel-bin/some/package/bin.runfiles/project/",
				"bazel-bin/some/package/bin.runfiles/project/data-file",
				"data-file", // bazel-bin should be preferred.
			},
			"bazel-bin/some/package/bin.runfiles/project",
			true,
		},
		{
			"BazelBinConfigurationInPath",
			[]string{
				"bazel-bin/some/package/amd64/bin.runfiles/project/",
				"bazel-bin/some/package/arm64/bin.runfiles/project/",
				"bazel-bin/some/package/arm64/bin.runfiles/project/data-file",
				"bazel-bin/some/package/powerpc/bin.runfiles/project/",
				"data-file", // bazel-bin should be preferred.
			},
			"bazel-bin/some/package/arm64/bin.runfiles/project",
			true,
		},
	}
	for _, d := range testData {
		t.Run(d.name, func(t *testing.T) {
			cleanup, err := makeAndEnterTempdir()
			if err != nil {
				t.Fatal(err)
			}
			defer cleanup()

			if err := createPaths(d.pathsToCreate); err != nil {
				t.Fatal(err)
			}

			runfiles, ok := findRunfiles("project", "some/package", "bin", "data-file")
			if filepath.Clean(runfiles) != filepath.Clean(d.wantRunfiles) || ok != d.wantOk {
				t.Errorf("Got %s, %v; want %s, %v", runfiles, ok, d.wantRunfiles, d.wantOk)
			}
		})
	}
}

func TestEnterRunfiles(t *testing.T) {
	cleanup, err := makeAndEnterTempdir()
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()

	pathsToCreate := []string{
		"bazel-bin/some/package/bin.runfiles/project/",
		"bazel-bin/some/package/bin.runfiles/project/data-file",
	}
	if err := createPaths(pathsToCreate); err != nil {
		t.Fatal(err)
	}

	if err := EnterRunfiles("project", "some/package", "bin", "data-file"); err != nil {
		t.Fatalf("Cannot enter runfiles tree: %v", err)
	}
	// The cleanup routine returned by makeAndEnterTempdir restores the working directory from
	// the beginning of the test, so we don't have to worry about it here.

	if _, err := os.Lstat("data-file"); err != nil {
		wd, err := os.Getwd()
		if err != nil {
			t.Errorf("failed to get current working directory: %v", err)
		}
		t.Errorf("data-file not found in current directory (%s); entered invalid runfiles tree?", wd)
	}
}
