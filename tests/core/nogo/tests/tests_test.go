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

package importpath_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test", "nogo")

go_library(
    name = "simple_lib",
	srcs = ["simple_lib.go"],
	importpath = "example.com/simple",
)

go_test(
    name = "simple_test",
    size = "small",
    srcs = ["simple_test.go"],
    embed = [":simple_lib"],
)

go_test(
    name = "super_simple_test",
    size = "small",
    srcs = ["super_simple_test.go"],
)

nogo(
    name = "nogo",
    vet = True,
    visibility = ["//visibility:public"],
)
-- simple_lib.go --
package simple

func Foo() {}
-- simple_test.go --
package simple_test

import (
	"testing"

	"example.com/simple"
)

func TestFoo(t *testing.T) {
    simple.Foo()
}
-- super_simple_test.go --
package super_simple_test

import (
	"testing"
)

func TestFoo(t *testing.T) {
}
`,
		Nogo: `@//:nogo`,
	})
}

func TestExternalTestWithFullImportpath(t *testing.T) {
	if out, err := bazel_testing.BazelOutput("test", "//:all"); err != nil {
		println(string(out))
		t.Fatal(err)
	}
}

func TestEmptyExternalTest(t *testing.T) {
	if out, err := bazel_testing.BazelOutput("test", "//:all"); err != nil {
		println(string(out))
		t.Fatal(err)
	}
}
