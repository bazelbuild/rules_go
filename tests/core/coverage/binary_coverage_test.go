// Copyright 2019 The Bazel Authors. All rights reserved.
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

package binary_coverage_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "hello",
    srcs = ["hello.go"],
    out = "hello",
)
-- hello.go --
package main

import "fmt"

func main() {
	fmt.Println(A())
}

func A() int { return 12 }

func B() int { return 34 }
`,
	})
}

func Test(t *testing.T) {
	// Check that we can build a binary with coverage instrumentation enabled.
	args := []string{
		"build",
		"--collect_code_coverage",
		"--instrumentation_filter=.*",
		"//:hello",
	}
	if err := bazel_testing.RunBazel(args...); err != nil {
		t.Fatal(err)
	}

	// Check that we can build with `bazel coverage`. It will fail because
	// there are no tests.
	args = []string{
		"coverage",
		"//:hello",
	}
	if err := bazel_testing.RunBazel(args...); err == nil {
		t.Fatal("got success; want failure")
	} else if bErr, ok := err.(*bazel_testing.StderrExitError); !ok {
		t.Fatalf("got %v; want StderrExitError", err)
	} else if code := bErr.Err.ExitCode(); code != 4 {
		t.Fatalf("got code %d; want code 4 (no tests found)", code)
	}
}
