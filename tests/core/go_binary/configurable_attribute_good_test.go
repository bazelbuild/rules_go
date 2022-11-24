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

package configurable_attribute_good_test

import (
	"runtime"
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
        "lib_nopenguins.go",
        "lib_penguins.go",
    ],
    gotags = select({
        "@io_bazel_rules_go//go/platform:linux": ["penguins"],
        "//conditions:default": ["nopenguins"],
    }),
)

-- main.go --
package main

import "fmt"

func main() {
  fmt.Println(message())
}

-- lib_penguins.go --
// +build penguins

package main

func message() string {
  return "Penguins are great"
}


-- lib_nopenguins.go --
// +build !penguins

package main

func message() string {
  return "Penguins smell fishy'"
}
`,
	})
}

func TestConfigurableGotagsAttribute(t *testing.T) {
	outBytes, err := bazel_testing.BazelOutput("run", "//:main")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}
	out := string(outBytes)
	os := runtime.GOOS
	switch os {
	case "linux":
		if !strings.Contains(out, "Penguins are great") {
			t.Fatalf("Wanted penguin executable, but output was: %s", out)
		}
	default:
		if !strings.Contains(out, "Penguins smell fishy") {
			t.Fatalf("Wanted nopenguin executable, but output was: %s", out)
		}
	}
}
