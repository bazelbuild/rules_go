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

package genrule_go_binary_test

import (
	"bytes"
	"io/ioutil"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

const (
	genruleOut           = "genrule_out"
	successMsg           = "success"
	stampNotAppliedMsg   = "Stamp == stampNotApplied"
	stampNotEvaluatedMsg = "Stamp == setButUnevaluated"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- .bazelrc --
build:stamp --stamp
build:stamp --workspace_status_command="sh status.sh"
# Note that run and test both inherrit bazelrc options from build
-- status.sh --
echo "STABLE_STAMPED_VARIABLE ` + successMsg + `"
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary")
go_binary(
    name = "stamp",
    srcs = ["stamp.go"],
    out = "stamp",
    x_defs = {
        "main.stamp": "{STABLE_STAMPED_VARIABLE}",
    },
)
genrule(
    name = "genrule",
    cmd = "$(location :stamp) > $@",
    tools = [":stamp"],
    outs = ["` + genruleOut + `"],
)
-- stamp.go --
package main

import "fmt"

const setButUnevaluated = "{STABLE_STAMPED_VARIABLE}"
const stampNotApplied = "STAMP_NOT_APPLIED"

var stamp string = stampNotApplied

func main() {
	if stamp == stampNotApplied {
		panic("` + stampNotAppliedMsg + `")
	}
	// TODO(issue/2224): Uncomment this line to demonstrate stamping issues.
	//if stamp == setButUnevaluated {
	//	panic("` + stampNotEvaluatedMsg + `")
	//}
	//fmt.Print(stamp)
	fmt.Print("` + successMsg + `")
}
`,
	})
}

func Test(t *testing.T) {
	// Running the go binary without stamping should cause the stampNotAppliedMsg error.
	if err := bazel_testing.RunBazel(
		"run",
		"//:stamp",
	); err == nil {
		//t.Fatal("got success; want failure")
	} else if bErr, ok := err.(*bazel_testing.StderrExitError); !ok {
		t.Fatalf("got %v; want StderrExitError", err)
	} else if code := bErr.Err.ExitCode(); code != 2 {
		t.Fatalf("got code %d; want code 2 (test failure)\n%v", code, bErr.Error())
	} else if !strings.Contains(bErr.Error(), stampNotEvaluatedMsg) {
		t.Fatalf("got %q; should contain %q", bErr.Error(), stampNotEvaluatedMsg)
	}

	// Running the go binary with stamping should work just fine.
	if err := bazel_testing.RunBazel(
		"run",
		"--config=stamp",
		"//:stamp",
	); err != nil {
		t.Fatal(err)
	}

	// Build the genrule that has the stamped binary transitively.
	if err := bazel_testing.RunBazel(
		"build",
		"--config=stamp",
		"//:genrule",
	); err != nil {
		t.Fatal(err)
	}

	var genruleFilePath string
	if info, err := bazel_testing.BazelInfo(); err != nil {
		t.Fatal(err)
	} else {
		genruleFilePath = info["bazel-bin"]
	}

	if output, err := ioutil.ReadFile(genruleFilePath + "/" + genruleOut); err != nil {
		t.Fatal(err)
	} else if !bytes.Equal(output, []byte(successMsg)) {
		t.Fatalf("got %q; want %q", output, successMsg)
	}
}
