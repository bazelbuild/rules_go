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
	"errors"
	"fmt"
	"io/ioutil"
	"os"
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
	file := "go/tools/bazel/empty.txt"
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
	// prefix := "new/temp/dir"
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

func TestPythonManifest(t *testing.T) {
	cleanup, err := makeAndEnterTempdir()
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()

	err = ioutil.WriteFile("MANIFEST",
		// all on one line to make sure the whitespace stays exactly as in the source file
		[]byte("__init__.py \n__main__/external/__init__.py \n__main__/external/rules_python/__init__.py \n__main__/external/rules_python/python/__init__.py \n__main__/external/rules_python/python/runfiles/__init__.py \n__main__/external/rules_python/python/runfiles/runfiles.py C:/users/sam/_bazel_sam/pj4cl7d4/external/rules_python/python/runfiles/runfiles.py\n__main__/go_cat_/go_cat.exe C:/users/sam/_bazel_sam/pj4cl7d4/execroot/__main__/bazel-out/x64_windows-opt-exec-2B5CBBC6/bin/go_cat_/go_cat.exe\n__main__/important.txt C:/users/sam/dev/rules_go_runfiles_repro/important.txt\n__main__/parent.exe C:/users/sam/_bazel_sam/pj4cl7d4/execroot/__main__/bazel-out/x64_windows-opt-exec-2B5CBBC6/bin/parent.exe\n__main__/parent.py C:/users/sam/dev/rules_go_runfiles_repro/parent.py\n__main__/parent.zip C:/users/sam/_bazel_sam/pj4cl7d4/execroot/__main__/bazel-out/x64_windows-opt-exec-2B5CBBC6/bin/parent.zip\nrules_python/__init__.py \nrules_python/python/__init__.py \nrules_python/python/runfiles/__init__.py \nrules_python/python/runfiles/runfiles.py C:/users/sam/_bazel_sam/pj4cl7d4/external/rules_python/python/runfiles/runfiles.py"),
		os.FileMode(0644),
	)
	if err != nil {
		t.Fatalf("Failed to write sample manifest: %v", err)
	}

	originalEnvVar := os.Getenv(RUNFILES_MANIFEST_FILE)
	defer func() {
		if err = os.Setenv(RUNFILES_MANIFEST_FILE, originalEnvVar); err != nil {
			t.Fatalf("Failed to reset environment: %v", err)
		}
	}()

	if err = os.Setenv(RUNFILES_MANIFEST_FILE, "MANIFEST"); err != nil {
		t.Fatalf("Failed to set manifest file environement variable: %v", err)
	}

	initRunfiles()

	if runfiles.err != nil {
		t.Errorf("failed to init runfiles: %v", runfiles.err)
	}

	entry, ok := runfiles.index.GetIgnoringWorkspace("important.txt")
	if !ok {
		t.Errorf("failed to locate runfile %s in index", "important.txt")
	}

	if entry.Workspace != "__main__" {
		t.Errorf("incorrect workspace for runfile. Expected: %s, actual %s", "__main__", entry.Workspace)
	}
}

func TestSpliceDelimitedOSArgs(t *testing.T) {
	testData := map[string]struct {
		initial []string
		want    []string
		final   []string
		wantErr error
	}{
		"no args": {
			[]string{},
			[]string{},
			[]string{},
			nil,
		},
		"empty splice": {
			[]string{"-begin_files", "-end_files"},
			[]string{},
			[]string{},
			nil,
		},
		"removes inner args": {
			[]string{"-begin_files", "a", "-end_files"},
			[]string{"a"},
			[]string{},
			nil,
		},
		"preserves outer args": {
			[]string{"a", "-begin_files", "b", "c", "-end_files", "d"},
			[]string{"b", "c"},
			[]string{"a", "d"},
			nil,
		},
		"complains about missing end delimiter": {
			[]string{"-begin_files"},
			[]string{},
			[]string{},
			errors.New("error: -begin_files, -end_files not set together or in order"),
		},
		"complains about missing begin delimiter": {
			[]string{"-end_files"},
			[]string{},
			[]string{},
			errors.New("error: -begin_files, -end_files not set together or in order"),
		},
		"complains about out-of-order delimiter": {
			[]string{"-end_files", "-begin_files"},
			[]string{},
			[]string{},
			errors.New("error: -begin_files, -end_files not set together or in order"),
		},
		"-- at middle": {
			[]string{"-begin_files", "a", "b", "--", "-end_files"},
			[]string{},
			[]string{},
			errors.New("error: -begin_files, -end_files not set together or in order"),
		},
		"-- at beginning": {
			[]string{"--", "-begin_files", "a", "-end_files"},
			[]string{},
			[]string{"--", "-begin_files", "a", "-end_files"},
			nil,
		},
	}
	for name, tc := range testData {
		t.Run(name, func(t *testing.T) {
			os.Args = tc.initial
			got, err := SpliceDelimitedOSArgs("-begin_files", "-end_files")
			if err != nil {
				if tc.wantErr == nil {
					t.Fatalf("unexpected err: %v", err)
				}
				if tc.wantErr.Error() != err.Error() {
					t.Fatalf("err: want %v, got %v", tc.wantErr, err)
				}
				return
			}
			if len(tc.want) != len(got) {
				t.Fatalf("len(want: %d, got %d", len(tc.want), len(got))
			}
			for i, actual := range got {
				expected := tc.want[i]
				if expected != actual {
					t.Errorf("%d: want %v, got %v", i, expected, actual)
				}
			}
			if len(tc.final) != len(os.Args) {
				t.Fatalf("len(want: %d, os.Args %d", len(tc.final), len(os.Args))
			}
			for i, actual := range os.Args {
				expected := tc.final[i]
				if expected != actual {
					t.Errorf("%d: want %v, os.Args %v", i, expected, actual)
				}
			}
		})
	}
}
