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

package testinit

// This package must have no deps beyond Go SDK.
import (
	"log"
	"os"
	"path/filepath"
	"runtime"
)

var (
	// Initialized by linker.
	RunDir string
)

// This initializer runs before any user packages.
func init() {
	// Check if we're being run by Bazel and change directories if so.
	// TEST_SRCDIR and TEST_WORKSPACE are set by the Bazel test runner, so that makes a decent proxy.
	testSrcdir, hasSrcDir := os.LookupEnv("TEST_SRCDIR")
	testWorkspace, hasWorkspace := os.LookupEnv("TEST_WORKSPACE")
	if hasSrcDir && hasWorkspace && RunDir != "" {
		abs := RunDir
		if !filepath.IsAbs(RunDir) {
			abs = filepath.Join(testSrcdir, testWorkspace, RunDir)
		}
		err := os.Chdir(abs)
		// Ignore the Chdir err when on Windows, since it might have have runfiles symlinks.
		// https://github.com/bazelbuild/rules_go/pull/1721#issuecomment-422145904
		if err != nil && runtime.GOOS != "windows" {
			log.Fatalf("could not change to test directory: %v", err)
		}
		if err == nil {
			_ = os.Setenv("PWD", abs)
		}
	}

	// Setup the bazel tmpdir as the go tmpdir.
	if tmpDir, ok := os.LookupEnv("TEST_TMPDIR"); ok {
		_ = os.Setenv("TMPDIR", tmpDir)
	}
}
