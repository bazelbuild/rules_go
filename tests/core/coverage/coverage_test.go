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

package coverage_test

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
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_test(
    name = "a_test",
    srcs = ["a_test.go"],
    embed = [":a"],
)

go_test(
    name = "a_test_cross",
    srcs = ["a_test.go"],
    embed = [":a"],
    goarch = "386",
    goos = "linux",
    pure = "on",
    tags = ["manual"],
)

go_library(
    name = "a",
    srcs = ["a.go"],
    importpath = "example.com/coverage/a",
    deps = [":b"],
)

go_library(
    name = "b",
    srcs = ["b.go"],
    importpath = "example.com/coverage/b",
    deps = [":c"],
)

go_library(
    name = "c",
    srcs = ["c.go"],
    importpath = "example.com/coverage/c",
)

-- a_test.go --
package a

import "testing"

func TestA(t *testing.T) {
	ALive()
}

-- a.go --
package a

import "example.com/coverage/b"

func ALive() int {
	return b.BLive()
}

func ADead() int {
	return b.BDead()
}

-- b.go --
package b

import "example.com/coverage/c"

func BLive() int {
	return c.CLive()
}

func BDead() int {
	return c.CDead()
}

-- c.go --
package c

func CLive() int {
	return 12
}

func CDead() int {
	return 34
}

`,
	})
}

func TestCoverage(t *testing.T) {
	if err := bazel_testing.RunBazel("coverage", "--instrumentation_filter=-//:b", ":a_test"); err != nil {
		t.Fatal(err)
	}

	coveragePath := filepath.FromSlash("bazel-testlogs/a_test/coverage.dat")
	coverageData, err := ioutil.ReadFile(coveragePath)
	if err != nil {
		t.Fatal(err)
	}
	for _, include := range []string{
		"example.com/coverage/a/a.go:",
		"example.com/coverage/c/c.go:",
	} {
		if !bytes.Contains(coverageData, []byte(include)) {
			t.Errorf("%s: does not contain %q\n", coveragePath, include)
		}
	}
	for _, exclude := range []string{
		"example.com/coverage/b/b.go:",
	} {
		if bytes.Contains(coverageData, []byte(exclude)) {
			t.Errorf("%s: contains %q\n", coveragePath, exclude)
		}
	}
}

func TestCrossBuild(t *testing.T) {
	if err := bazel_testing.RunBazel("build", "--collect_code_coverage", "--instrumentation_filter=-//:b", "//:a_test_cross"); err != nil {
		t.Fatal(err)
	}
}
