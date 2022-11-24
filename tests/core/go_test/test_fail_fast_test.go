// Copyright 2022 The Bazel Authors. All rights reserved.
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

package test_fail_fast_test

import (
	"bytes"
	"io/ioutil"
	"path/filepath"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "fail_fast_test",
    srcs = ["fail_fast_test.go"],
)

-- fail_fast_test.go --
package test_fail_fast

import "testing"

func TestShouldFail(t *testing.T) {
	t.Fail()
}

func TestShouldNotRun(t *testing.T) {
	t.Fail()
}
`,
	})
}

func Test(t *testing.T) {
	if err := bazel_testing.RunBazel("test", "//:fail_fast_test", "--test_runner_fail_fast"); err == nil {
		t.Fatal("got success; want failure")
	} else if bErr, ok := err.(*bazel_testing.StderrExitError); !ok {
		t.Fatalf("got %v; want StderrExitError", err)
	} else if code := bErr.Err.ExitCode(); code != 3 {
		t.Fatalf("got code %d; want code 3", code)
	}

	logPath := filepath.FromSlash("bazel-testlogs/fail_fast_test/test.log")
	logData, err := ioutil.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}

	if !bytes.Contains(logData, []byte("TestShouldFail")) {
		t.Fatalf("test log does not contain 'TestShouldFail': %q", logData)
	}

	if bytes.Contains(logData, []byte("TestShouldNotRun")) {
		t.Fatalf("test log contains 'TestShouldNotRun' but should not: %q", logData)
	}
}
