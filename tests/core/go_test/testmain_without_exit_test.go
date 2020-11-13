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

package testmain_without_exit

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "main_without_exit_test",
    srcs = ["main_without_exit_test.go"],
)

-- main_without_exit_test.go --
package test_main_without_exit

import "testing"

func TestMain(m *testing.M) {
	m.Run()
}

func TestShouldFail(t *testing.T) {
	t.Fail()
}
`,
	})
}

func Test(t *testing.T) {
	err := bazel_testing.RunBazel("test", "//:main_without_exit_test")
	if err == nil {
		t.Fatal("expected bazel test to have failed")
	}

	if xerr, ok := err.(*bazel_testing.StderrExitError); !ok || xerr.Err.ExitCode() != 3 {
		t.Fatalf("expected bazel tests to fail with exit code 3 (TESTS_FAILED), got: %s", err)
	}
}
