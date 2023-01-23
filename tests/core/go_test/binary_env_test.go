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

package binary_env_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- src/BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")
go_binary(
    name = "main",
	srcs = ["env.go"],
	env = {"FOO": "bar"},
)
-- src/env.go --
package main

import (
	"log"
	"os"
)

func main() {
	v := os.Getenv("FOO")
	if v != "bar" {
		log.Fatalf("FOO was not equal to bar")
	}
}
`,
	})
}

func TestBinaryEnv(t *testing.T) {
	if err := bazel_testing.RunBazel("run", "//src:main"); err != nil {
		t.Fatal(err)
	}
}
