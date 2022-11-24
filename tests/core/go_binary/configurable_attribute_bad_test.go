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

package configurable_attribute_bad_test

import (
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "main",
    srcs = [
        "main.go",
    ],
    goos = "darwin",
    goarch = "amd64",
    gotags = select({
        "@io_bazel_rules_go//go/platform:linux": ["penguins"],
        "//conditions:default": ["nopenguins"],
    }),
)

-- main.go --
package main

import "fmt"

func main() {
  fmt.Println("Howdy")
}
`,
	})
}

func TestConfigurableGotagsAttribute(t *testing.T) {
	_, err := bazel_testing.BazelOutput("build", "//:main")
	if err == nil {
		t.Fatal("Want error")
	}
	eErr, ok := err.(*bazel_testing.StderrExitError)
	if !ok {
		t.Fatalf("Want StderrExitError but got %v", err)
	}
	stderr := eErr.Error()
	want := "Cannot use select for go_binary with goos/goarch set, but gotags was a select"
	if !strings.Contains(stderr, want) {
		t.Fatalf("Want error message containing %q but got %v", want, stderr)
	}
}
