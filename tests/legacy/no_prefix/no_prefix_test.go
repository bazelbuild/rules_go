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

package no_prefix_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

const mainFiles = `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["no_prefix.go"],
    importpath = "github.com/bazelbuild/rules_go/tests/no_prefix",
)

go_test(
    name = "go_default_xtest",
    srcs = ["no_prefix_test.go"],
    deps = [":go_default_library"],
)

go_binary(
    name = "cmd",
    srcs = ["cmd.go"],
    deps = [":go_default_library"],
)

-- no_prefix.go --
package no_prefix

-- no_prefix_test.go --
package no_prefix_test

-- cmd.go --
package main

import _ "github.com/bazelbuild/rules_go/tests/no_prefix"

func main() {
}
`

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: mainFiles,
	})
}

func TestBuild(t *testing.T) {
	if err := bazel_testing.RunBazel("build", ":all"); err != nil {
		t.Fatal(err)
	}
}
