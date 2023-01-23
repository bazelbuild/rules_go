// Copyright 2023 The Bazel Authors. All rights reserved.
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

package go_bin_runner_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{})
}

func TestGoEnv(t *testing.T) {
	// Set an invalid GOROOT to test that the //go target still finds the expected hermetic GOROOT.
	os.Setenv("GOROOT", "invalid")

	bazelInfoOut, err := bazel_testing.BazelOutput("info", "output_base")
	if err != nil {
		t.Fatal(err)
	}
	outputBase := strings.TrimSpace(string(bazelInfoOut))

	goEnvOut, err := bazel_testing.BazelOutput("run", "@io_bazel_rules_go//go", "--", "env", "GOROOT")
	if err != nil {
		t.Fatal(err)
	}

	goRoot := strings.TrimSpace(string(goEnvOut))
	if goRoot != filepath.Join(outputBase, "external", "go_sdk") {
		t.Fatalf("GOROOT was not equal to %s", filepath.Join(outputBase, "external", "go_sdk"))
	}
}
