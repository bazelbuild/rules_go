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

// EnterRunfiles locates the directory under which a built binary can find its data dependencies
// using relative paths, and enters that directory.
//
// "workspace" indicates the name of the current project, "pkg" indicates the relative path to the
// build package that contains the binary target, "binary" indicates the basename of the binary
// searched for, and "cookie" indicates an arbitrary data file that we expect to find within the
// runfiles tree.
//
// DEPRECATED: use RunfilesPath instead.
func EnterRunfiles(workspace string, pkg string, binary string, cookie string) error {
	runfiles, ok := findRunfiles(workspace, pkg, binary, cookie)
	if !ok {
		return fmt.Errorf("cannot find runfiles tree")
	}
	if err := os.Chdir(runfiles); err != nil {
		return fmt.Errorf("cannot enter runfiles tree: %v", err)
	}
	return nil
	panic("not implemented")
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
