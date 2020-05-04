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

package flag_test

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"os/exec"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "bad_printf",
    srcs = ["bad_printf.go"],
)

-- bad_printf.go --
package main

import "fmt"

func main() {
	// printf analyzer should report an error here
	fmt.Printf("hello, %s!\n")
}
`,
	})
}

func Test(t *testing.T) {
	workspaceData, err := ioutil.ReadFile("WORKSPACE")
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		desc                    string
		workspaceNogo, flagNogo string
		wantStderr              string
	}{
		{
			desc: "none",
		},
		{
			desc:          "workspace_only",
			workspaceNogo: "@io_bazel_rules_go//:tools_nogo",
			wantStderr:    "bad_printf.go:7:2: Printf format",
		},
		{
			desc:       "flag_only",
			flagNogo:   "@io_bazel_rules_go//:tools_nogo",
			wantStderr: "bad_printf.go:7:2: Printf format",
		},
		{
			desc:          "flag_overrides_workspace",
			workspaceNogo: "@io_bazel_rules_go//:default_nogo",
			flagNogo:      "@io_bazel_rules_go//:tools_nogo",
			wantStderr:    "bad_printf.go:7:2: Printf format",
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			var err error
			if test.workspaceNogo == "" {
				err = ioutil.WriteFile("WORKSPACE", workspaceData, 0666)
			} else {
				origLine := []byte("\ngo_register_toolchains()\n")
				modifiedLine := []byte(fmt.Sprintf("\ngo_register_toolchains(nogo = \"%s\")\n", test.workspaceNogo))
				data := bytes.Replace(workspaceData, origLine, modifiedLine, 1)
				err = ioutil.WriteFile("WORKSPACE", data, 0666)
			}
			if err != nil {
				t.Fatal(err)
			}

			args := []string{"build"}
			if test.flagNogo != "" {
				args = append(args, "--@io_bazel_rules_go//go/config:nogo="+test.flagNogo)
			}
			args = append(args, ":bad_printf")
			err = bazel_testing.RunBazel(args...)
			if test.wantStderr == "" && err != nil {
				t.Fatalf("unexpected error running bazel: %v", err)
			} else if test.wantStderr != "" {
				if err == nil {
					t.Fatal("unexpected success running bazel")
				}
				var xerr *exec.ExitError
				if !errors.As(err, &xerr) {
					t.Fatalf("unexpected error running bazel: %v", err)
				}
				if !bytes.Contains(xerr.Stderr, []byte(test.wantStderr)) {
					t.Fatalf("got error:\n%s\nwant error containing %q", err)
				}
			}
		})
	}
}
