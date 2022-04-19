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

package configurable_attribute_test

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
    srcs = ["main.go"],
    goos = select({
        "//conditions:default": "darwin",
    }),
    goarch = "amd64",
)

go_binary(
    name = "configurable_srcs",
    srcs = select({
        "@io_bazel_rules_go//go/platform:darwin": ["main_darwin.go"],
        "//conditions:default": ["main_default.go"],
    }),
    goos = select({
        "//conditions:default": "darwin",
    }),
    goarch = "amd64",
)

-- main.go --
package main

import "fmt"

func main() {
  fmt.Println("Hello, World!")
}
-- main_darwin.go --
package main

import "fmt"

func main() {
    fmt.Println("Hello from darwin, an Apple-shaped operating system")
}
-- main_default.go --
package main

import "fmt"

func main() {
    fmt.Println("Hello from another operating systems, you'll never find half a worm in this one")
}
`,
	})
}

func TestConfigurableGOOSAttribute(t *testing.T) {
	outBytes, err := bazel_testing.BazelOutput("run", "--run_under=file -L", "//:main")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}
	out := string(outBytes)
	if !strings.Contains(out, "Mach-O 64-bit") {
		t.Fatalf("Wanted darwin executable but got: %s", out)
	}
}

func TestConfigurableSrcsWithGOOSTransition(t *testing.T) {
	outBytes, err := bazel_testing.BazelOutput("run", "--run_under=strings", "//:configurable_srcs")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}
	out := string(outBytes)
	wantSubstr := "Apple-shaped"
	if !strings.Contains(out, wantSubstr) {
		t.Fatalf("Wanted executable containing the string %q", wantSubstr)
	}
}
