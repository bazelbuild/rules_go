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

package config_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Nogo: "@io_bazel_rules_go//:tools_nogo",
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_binary(
    name = "pure_bin",
    srcs = ["pure_bin.go"],
    pure = "on",
    deps = [":pure_lib"],
)

go_library(
    name = "pure_lib",
    srcs = ["pure_lib.go"],
    importpath = "example.com/nogo/config/pure_lib",
)    

-- pure_bin.go --
package main

import _ "example.com/nogo/config/pure_lib"

func main() {
}

-- pure_lib.go --
package pure_lib

`,
	})
}

func TestPureAspect(t *testing.T) {
	if err := bazel_testing.RunBazel("build", "//:pure_bin"); err != nil {
		t.Fatal(err)
	}
}
