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

package race_test

import (
	"bytes"
	"fmt"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

go_library(
    name = "racy",
    srcs = [
        "race_off.go",
        "race_on.go",
        "racy.go",
        "empty.s", # verify #2143
    ],
    importpath = "example.com/racy",
)

go_binary(
    name = "racy_cmd",
    srcs = ["main.go"],
    embed = [":racy"],
)

go_binary(
    name = "racy_cmd_race_mode",
    srcs = ["main.go"],
    embed = [":racy"],
    race = "on",
)

go_test(
    name = "racy_test",
    srcs = ["racy_test.go"],
    embed = [":racy"],
)

go_test(
    name = "racy_test_race_mode",
    srcs = ["racy_test.go"],
    embed = [":racy"],
    race = "on",
)

-- race_off.go --
// +build !race

package main

const RaceEnabled = false

-- race_on.go --
// +build race

package main

const RaceEnabled = true

-- racy.go --
package main

import (
	"flag"
	"fmt"
	"os"
)

var wantRace = flag.Bool("wantrace", false, "")

func Race() {
	if *wantRace != RaceEnabled {
		fmt.Fprintf(os.Stderr, "!!! -wantrace is %v, but RaceEnabled is %v\n", *wantRace, RaceEnabled)
		os.Exit(1)
	}

	done := make(chan bool)
	m := make(map[string]string)
	m["name"] = "world"
	go func() {
		m["name"] = "data race"
		done <- true
	}()
	fmt.Println("Hello,", m["name"])
	<-done
}

-- main.go --
package main

import "flag"

func main() {
	flag.Parse()
	Race()
}

-- racy_test.go --
package main

import "testing"

func TestRace(t *testing.T) {
	Race()
}

-- empty.s --
`,
	})
}

func Test(t *testing.T) {
	for _, test := range []struct {
		desc, cmd, target     string
		featureFlag, wantRace bool
	}{
		{
			desc:   "cmd_auto",
			cmd:    "run",
			target: "//:racy_cmd",
		}, {
			desc:     "cmd_attr",
			cmd:      "run",
			target:   "//:racy_cmd_race_mode",
			wantRace: true,
		}, {
			desc:        "cmd_feature",
			cmd:         "run",
			target:      "//:racy_cmd",
			featureFlag: true,
			wantRace:    true,
		}, {
			desc:   "test_auto",
			cmd:    "test",
			target: "//:racy_test",
		}, {
			desc:     "test_attr",
			cmd:      "test",
			target:   "//:racy_test_race_mode",
			wantRace: true,
		}, {
			desc:        "test_feature",
			cmd:         "test",
			target:      "//:racy_test",
			featureFlag: true,
			wantRace:    true,
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			args := []string{test.cmd}
			if test.featureFlag {
				args = append(args, "--feature=race")
			}
			args = append(args, test.target)
			if test.cmd == "test" {
				args = append(args, fmt.Sprintf("--test_arg=-wantrace=%v", test.wantRace))
			} else {
				args = append(args, "--", fmt.Sprintf("-wantrace=%v", test.wantRace))
			}
			cmd := bazel_testing.BazelCmd(args...)
			stderr := &bytes.Buffer{}
			cmd.Stderr = stderr
			if err := cmd.Run(); err != nil {
				if bytes.Contains(stderr.Bytes(), []byte("!!!")) {
					t.Fatalf("error running %s:\n%s", strings.Join(cmd.Args, " "), stderr.Bytes())
				} else if !test.wantRace {
					t.Fatalf("error running %s without race enabled\n%s", strings.Join(cmd.Args, " "), stderr.Bytes())
				}
			} else if test.wantRace {
				t.Fatalf("command %s with race enabled did not fail", strings.Join(cmd.Args, " "))
			}
		})
	}
}
