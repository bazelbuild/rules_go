// Copyright 2020 The Bazel Authors. All rights reserved.
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

package bzltestutil

// This package must have no deps beyond Go SDK.
import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

var (
	// Initialized by linker.
	RunDir string

	// Initial working directory.
	testExecDir string
)

// This function sets the current working directory to RunDir when the test
// executable is started by Bazel (when TEST_SRCDIR and TEST_WORKSPACE are set).
//
// This hides a difference between Bazel and 'go test': 'go test' starts test
// executables in the package source directory, while Bazel starts test
// executables in a directory made to look like the repository root directory.
// Tests frequently refer to testdata files using paths relative to their
// package directory, so open source tests frequently break unless they're
// written with Bazel specifically in mind (using go/runfiles).
//
// For this init function to work, it must be called before init functions
// in all user packages.
//
// In Go 1.20 and earlier, the package initialization order was underspecified,
// other than a requirement that each package is initialized after all its
// transitively imported packages. We relied on the linker initializing
// packages in the order their imports appeared in source, so we imported
// bzltestutil from the generated test main before other packages.
//
// In Go 1.21, the package initialization order was clarified, and the
// linker implementation was changed. See https://go.dev/doc/go1.21#language.
// The order is now affected by import path: packages with lexicographically
// lower import paths go first.
//
// To ensure this package is initialized before user code, we add the prefix
// '+initfirst/' to this package's path with the 'importmap' directive.
// '+' is the first allowed character that sorts higher than letters.
// Because we're using 'importmap' and not 'importpath', this hack does not
// affect .go source files.
func init() {
	var err error
	testExecDir, err = os.Getwd()
	if err != nil {
		panic(err)
	}

	// Check if we're being run by Bazel and change directories if so.
	// TEST_SRCDIR and TEST_WORKSPACE are set by the Bazel test runner, so that makes a decent proxy.
	testSrcDir, hasSrcDir := os.LookupEnv("TEST_SRCDIR")
	testWorkspace, hasWorkspace := os.LookupEnv("TEST_WORKSPACE")
	if hasSrcDir && hasWorkspace && RunDir != "" {
		abs := RunDir
		if !filepath.IsAbs(RunDir) {
			abs = filepath.Join(testSrcDir, testWorkspace, RunDir)
		}
		err := os.Chdir(abs)
		// Ignore the Chdir err when on Windows, since it might have have runfiles symlinks.
		// https://github.com/bazelbuild/rules_go/pull/1721#issuecomment-422145904
		if err != nil && runtime.GOOS != "windows" {
			panic(fmt.Sprintf("could not change to test directory: %v", err))
		}
		if err == nil {
			os.Setenv("PWD", abs)
		}
	}
}
