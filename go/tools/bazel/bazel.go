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

// Package bazel provides utilities for interacting with the surrounding Bazel environment.
package bazel

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
)

const TEST_SRCDIR = "TEST_SRCDIR"
const TEST_TMPDIR = "TEST_TMPDIR"
const TEST_WORKSPACE = "TEST_WORKSPACE"

var defaultTestWorkspace = ""

// Runfile returns an absolute path to the specified file in the runfiles directory of the running target.
// It searches the current working directory, RunfilesPath() directory, and RunfilesPath()/TestWorkspace().
// Returns an error if unable to locate RunfilesPath() or if the file does not exist.
func Runfile(path string) (string, error) {
	if _, err := os.Stat(path); err == nil {
		// absolute path or found in current working directory
		return path, nil
	}

	runfiles, err := RunfilesPath()
	if err != nil {
		return "", err
	}

	filename := filepath.Join(runfiles, path)
	if _, err := os.Stat(filename); err == nil {
		// found at RunfilesPath()/path
		return filename, nil
	}

	workspace, err := TestWorkspace()
	if err != nil {
		return "", err
	}

	filename = filepath.Join(runfiles, workspace, path)
	if _, err := os.Stat(filename); err == nil {
		// found at RunfilesPath()/TestWorkspace()/path
		return filename, nil
	}

	return "", fmt.Errorf("unable to find file %q", path)
}

// RunfilesPath return the path to the run files tree for this test.
// It returns an error if TEST_SRCDIR does not exist.
func RunfilesPath() (string, error) {
	if src, ok := os.LookupEnv(TEST_SRCDIR); ok {
		return src, nil
	}
	return "", fmt.Errorf("environment variable %q is not defined, are you running with bazel test", TEST_SRCDIR)
}

// NewTmpDir creates a new temporary directory in TestTmpDir().
func NewTmpDir(prefix string) (string, error) {
	return ioutil.TempDir(TestTmpDir(), prefix)
}

// TestTmpDir returns the path the Bazel test temp directory.
// If TEST_TMPDIR is not defined, it returns the OS default temp dir.
func TestTmpDir() string {
	if tmp, ok := os.LookupEnv(TEST_TMPDIR); ok {
		return tmp
	}
	return os.TempDir()
}

// TestWorkspace returns the name of the Bazel workspace for this test.
// If TEST_WORKSPACE is not defined, it returns an error.
func TestWorkspace() (string, error) {
	if ws, ok := os.LookupEnv(TEST_WORKSPACE); ok {
		return ws, nil
	}
	if defaultTestWorkspace != "" {
		return defaultTestWorkspace, nil
	}
	return "", fmt.Errorf("Unable to find environment variable TEST_WORKSPACE")
}

// SetDefaultTestWorkspace allows you to set a fake value for the
// environment variable TEST_WORKSPACE if it is not defined. This is useful
// when running tests on the command line and not through Bazel.
func SetDefaultTestWorkspace(w string) {
	defaultTestWorkspace = w
}

// getCandidates returns the list of all possible "prefix/suffix" paths where there might be an
// optional component in-between the two pieces.
//
// This function exists to cope with issues #1239 because we cannot tell where the built Go
// binaries are located upfront.
func getCandidates(prefix string, suffix string) []string {
	candidates := []string{filepath.Join(prefix, suffix)}
	if entries, err := ioutil.ReadDir(prefix); err == nil {
		for _, entry := range entries {
			candidate := filepath.Join(prefix, entry.Name(), suffix)
			candidates = append(candidates, candidate)
		}
	}
	return candidates
}

// FindBinary locates the given executable within bazel-bin or the current directory.
//
// "pkg" indicates the relative path to the build package that contains the binary target, and
// "binary" indicates the basename of the binary searched for.
func FindBinary(pkg string, binary string) (string, bool) {
	candidates := getCandidates(filepath.Join("bazel-bin", pkg), binary)
	candidates = append(candidates, getCandidates(pkg, binary)...)

	for _, candidate := range candidates {
		// Following symlinks here is intentional because Bazel generates symlinks in
		// general and we don't care about that.
		if fileInfo, err := os.Stat(candidate); err == nil {
			if fileInfo.Mode()&os.ModeType == 0 && fileInfo.Mode()&0100 != 0 {
				return candidate, true
			}
		}
	}
	return "", false
}

// findRunfiles locates the directory under which a built binary can find its data dependencies
// using relative paths.
func findRunfiles(workspace string, pkg string, binary string, cookie string) (string, bool) {
	candidates := getCandidates(filepath.Join("bazel-bin", pkg), filepath.Join(binary+".runfiles", workspace))
	candidates = append(candidates, ".")

	for _, candidate := range candidates {
		if _, err := os.Stat(filepath.Join(candidate, cookie)); err == nil {
			return candidate, true
		}
	}
	return "", false
}

// EnterRunfiles locates the directory under which a built binary can find its data dependencies
// using relative paths, and enters that directory.
//
// "workspace" indicates the name of the current project, "pkg" indicates the relative path to the
// build package that contains the binary target, "binary" indicates the basename of the binary
// searched for, and "cookie" indicates an arbitrary data file that we expect to find within the
// runfiles tree.
func EnterRunfiles(workspace string, pkg string, binary string, cookie string) error {
	runfiles, ok := findRunfiles(workspace, pkg, binary, cookie)
	if !ok {
		return fmt.Errorf("cannot find runfiles tree")
	}
	if err := os.Chdir(runfiles); err != nil {
		return fmt.Errorf("cannot enter runfiles tree: %v", err)
	}
	return nil
}
