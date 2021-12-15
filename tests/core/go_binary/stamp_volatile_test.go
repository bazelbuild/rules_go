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

package workspace_status_stamping

import (
	"os/exec"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
	name = "stable",
	srcs = ["main.go"],
	out = "stable",
	x_defs = {
		"Stable": "{STABLE_STAMP}",
		"Volatile": "{VOLATILE_STAMP}",
	},
)

go_binary(
	name = "volatile",
	srcs = ["main.go"],
	out  = "volatile",
	x_defs = {
		"Volatile": "{VOLATILE_STAMP}",
	}
)

-- main.go --
package main

import (
	"fmt"
)

var Stable = "UNSTAMPED"
var Volatile = "UNSTAMPED"

func main() {
	fmt.Println(Stable)
	fmt.Println(Volatile)
}
`,
	})
}

func setupWorkspaceStatus(t *testing.T) string {
	wss, ok := bazel.FindBinary("tests/core/go_binary", "stamp_workspace_status_bin")
	if !ok {
		t.Fatal("Failed locating workspace_status binary")
	}

	return wss
}

func wssFlag(cmd, stable, volatile string) string {
	return cmd + " " + stable + " " + volatile
}

type Stamp struct {
	Stable, Volatile string
}

func runBuild(t *testing.T, cmd, target string, s Stamp) Stamp {
	if err := bazel_testing.RunBazel("build", "--stamp", "--workspace_status_command", wssFlag(cmd, s.Stable, s.Volatile), target); err != nil {
		t.Fatal("Failed to build test binary", err)
	}

	bin := strings.TrimLeft(target, "/:")

	output, err := exec.Command("bazel-bin/" + bin).Output()
	if err != nil {
		t.Fatal("Failed running volatile binary", err)
	}

	vals := strings.Split(string(output), "\n")
	return Stamp{
		Stable:   vals[0],
		Volatile: vals[1],
	}
}

func TestStableStamp(t *testing.T) {
	wscmd := setupWorkspaceStatus(t)

	stamp1 := Stamp{
		Stable:   "STABLE_1",
		Volatile: "FIRST",
	}

	res1 := runBuild(t, wscmd, "//:stable", stamp1)
	res2 := runBuild(t, wscmd, "//:stable", Stamp{
		Stable:   "STABLE_2",
		Volatile: "SECOND",
	})
	for _, v := range []string{res1.Stable, res2.Stable} {
		if v == "UNSTAMPED" {
			t.Fatal("Expected stable stamp, got 'UNSTAMPED'")
		}
	}

	if res1.Stable == res2.Stable {
		t.Fatal("Failed due to volatile stamp changing on second build")
	}
}

func TestVolatileStamp(t *testing.T) {
	wscmd := setupWorkspaceStatus(t)

	stamp1 := Stamp{
		Stable:   "STABLE",
		Volatile: "FIRST",
	}

	res1 := runBuild(t, wscmd, "//:volatile", stamp1)
	res2 := runBuild(t, wscmd, "//:volatile", Stamp{
		Stable:   "STABLE",
		Volatile: "SECOND",
	})
	for _, v := range []string{res1.Volatile, res2.Volatile} {
		if v == "UNSTAMPED" {
			t.Fatal("Expected volatile stamp, got 'UNSTAMPED'")
		}
	}

	for _, v := range []string{res1.Stable, res2.Stable} {
		if v != "UNSTAMPED" {
			t.Fatal("Stable occured when not requested")
		}
	}

	if res1 != res2 {
		t.Fatal("Failed due to volatile stamp changing on second build")
	}
}
