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

package deps_test

import (
	"bytes"
	"regexp"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Nogo: "@//:nogo",
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "nogo")

nogo(
    name = "nogo",
    deps = [
        ":a",
        ":b",
        ":c",
    ],
    visibility = ["//visibility:public"],
)

go_library(
    name = "a",
    srcs = ["a.go"],
    importpath = "a",
    deps = [
        ":c",
        "@org_golang_x_tools//go/analysis"
    ],
    visibility = ["//visibility:public"],
)

go_library(
    name = "b",
    srcs = ["b.go"],
    importpath = "b",
    deps = [
        ":c",
        "@org_golang_x_tools//go/analysis"
    ],
    visibility = ["//visibility:public"],
)

go_library(
    name = "c",
    srcs = ["c.go"],
    importpath = "c",
    deps = [
        ":d",
        "@org_golang_x_tools//go/analysis"
    ],
    visibility = ["//visibility:public"],
)

go_library(
    name = "d",
    srcs = ["d.go"],
    importpath = "d",
    deps = ["@org_golang_x_tools//go/analysis"],
    visibility = ["//visibility:public"],
)

go_library(
    name = "src",
    srcs = ["src.go"],
    importpath = "src",
)

-- a.go --
package a

import (
	"c"
	"go/token"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "a",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "a %s", pass.ResultOf[c.Analyzer])
	return nil, nil
}

-- b.go --
package b

import (
	"c"
	"go/token"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "b",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "b %s", pass.ResultOf[c.Analyzer])
	return nil, nil
}

-- c.go --
package c

import (
	"d"
	"fmt"
	"go/token"
	"reflect"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:       "c",
	Doc:        "an analyzer that depends on d.Analyzer",
	Run:        run,
	Requires:   []*analysis.Analyzer{d.Analyzer},
	ResultType: reflect.TypeOf(""),
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "only printed once")
	return fmt.Sprintf("c %s", pass.ResultOf[d.Analyzer]), nil
}

-- d.go --
package d

import (
	"go/token"
	"reflect"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:       "d",
	Doc:        "an analyzer that does not depend on other analyzers",
	Run:        run,
	ResultType: reflect.TypeOf(""),
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "this should not be printed")
	return "d", nil
}

-- src.go --
package src

func Foo() int {
	return 1
}

`,
	})
}

func Test(t *testing.T) {
	cmd := bazel_testing.BazelCmd("build", "//:src")
	stderr := &bytes.Buffer{}
	cmd.Stderr = stderr
	if err := cmd.Run(); err == nil {
		t.Fatal("unexpected success")
	}

	for _, pattern := range []string{
		"a c d",
		"b c d",
		"only printed once",
	} {
		if matched, _ := regexp.Match(pattern, stderr.Bytes()); !matched {
			t.Errorf("output does not contain pattern: %s", pattern)
		}
	}
	if bytes.Contains(stderr.Bytes(), []byte("this should not be printed")) {
		t.Errorf("%q was printed", "this should not be printed")
	}
}
