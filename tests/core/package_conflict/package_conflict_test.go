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

package reproducibility_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "foo_de",
    importpath = "github.com/bazelbuild/rules_go/tests/core/package_conflict/foo",
    srcs = ["foo_de.go"],
)

go_library(
    name = "de",
    importpath = "github.com/bazelbuild/rules_go/tests/core/package_conflict/de",
    srcs = ["de.go"],
    deps = [":foo_de"],
)

go_library(
    name = "foo_en",
    importpath = "github.com/bazelbuild/rules_go/tests/core/package_conflict/foo",
    srcs = ["foo_en.go"],
)

go_library(
    name = "en",
    importpath = "github.com/bazelbuild/rules_go/tests/core/package_conflict/en",
    srcs = ["en.go"],
    deps = [":foo_en"],
)

go_binary(
    name = "main",
    srcs = ["main.go"],
    deps = [
        ":de",
        ":en",
    ],
)

-- foo_en.go --
package foo

import "fmt"

func SayHello() {
  fmt.Println("Hello, World!")
}

-- en.go --
package en

import "github.com/bazelbuild/rules_go/tests/core/package_conflict/foo"

func SayHello() {
  foo.SayHello()
}

-- foo_de.go --
package foo

import "fmt"

func SayHello() {
  fmt.Println("Hallo, Welt!")
}

-- de.go --
package de

import "github.com/bazelbuild/rules_go/tests/core/package_conflict/foo"

func SayHello() {
  foo.SayHello()
}

-- main.go --
package main

import (
  "github.com/bazelbuild/rules_go/tests/core/package_conflict/de"
  "github.com/bazelbuild/rules_go/tests/core/package_conflict/en"
)

func main() {
  de.SayHello()
  en.SayHello()
}
`,
	})
}

func runTest(t *testing.T, expectError bool, extraArgs ...string) {
	args := append([]string{"build", "//:main"}, extraArgs...)

	err := bazel_testing.RunBazel(args...)
	if expectError {
		if err == nil {
			t.Fatal("Expected error")
		}
	} else {
		if err != nil {
			t.Fatal(err)
		}
	}
}

func TestDefaultBehaviour(t *testing.T) {
	// TODO(#1374): Default to `true`.
	runTest(t, false)
}

func TestPackageConflictIsWarning(t *testing.T) {
	runTest(t, false, "--@io_bazel_rules_go//go/config:incompatible_package_conflict_is_error=False")
}

func TestPackageConflictIsError(t *testing.T) {
	runTest(t, true, "--@io_bazel_rules_go//go/config:incompatible_package_conflict_is_error=True")
}
