// Copyright 2023 The Bazel Authors. All rights reserved.
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

package pgo_test

import (
	_ "embed"
	"os"
	"path"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

//go:embed pgo.pprof
var pgoProfile []byte

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- src/BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_test")

go_binary(
    name = "pgo_with_profile",
    srcs = ["pgo.go"],
    pgoprofile = ":pgo.pprof",
)

go_binary(
    name = "pgo_without_profile",
    srcs = ["pgo.go"],
)

go_test(
    name = "compare_results_test",
    data = [
        ":pgo_with_profile",
        ":pgo_without_profile",
    ],
    srcs = ["compare_results_test.go"],
    deps = ["@io_bazel_rules_go//go/tools/bazel:go_default_library"],
)

-- src/pgo.go --
package main

import "fmt"

func main() {
  fmt.Println("Did you know that profile guided optimization was added to the go compiler in go version 1.20?")
}

-- src/compare_results_test.go --
package compare_results_test

import (
    "crypto/sha256"
    "os"
    "strings"
    "testing"

    "github.com/bazelbuild/rules_go/go/tools/bazel"
)

func TestResultsAreSame(t *testing.T) {
    rfs, err := bazel.ListRunfiles()
    if err != nil {
        t.Fatal(err)
    }

    var files []bazel.RunfileEntry
    for _, rf := range rfs {
        rf := rf
        s, err := os.Stat(rf.Path)
        if err != nil {
            t.Fatal(err)
        }
        if !s.IsDir() && !strings.HasPrefix(s.Name(), "compare_results_test") {
            files = append(files, rf)
        }
    }

    if len(files) != 2 {
        for i, rf := range files {
            t.Logf("files[%d] = %s", i, rf.Path)
        }
        t.Fatalf("expected 2 runfiles, got %d", len(files))
    }

    f1, err := os.ReadFile(files[0].Path)
    if err != nil {
        t.Fatal(err)
    }

    f2, err := os.ReadFile(files[1].Path)
    if err != nil {
        t.Fatal(err)
    }

    a, b := sha256.Sum256(f1), sha256.Sum256(f2)

    if a == b {
        t.Fatal("outputs are equal when they should be different")
    }
}
`,
	})
}

func TestGoBinaryOutputWithPgoProfileDiffersFromGoBinaryWithoutPgoProfile(t *testing.T) {
	// Write the pgo.pprof file.
	// This must be done as txtar changes the content of the pprof file and it could not be parsed.
	pwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path.Join(pwd, "src", "pgo.pprof"), pgoProfile, 0644); err != nil {
		t.Fatal(err)
	}

	// Ensure both targets can be built
	if err := bazel_testing.RunBazel("build", "//src:pgo_without_profile"); err != nil {
		t.Fatal(err)
	}
	if err := bazel_testing.RunBazel("build", "//src:pgo_with_profile"); err != nil {
		t.Fatal(err)
	}

	// Run the comparison test.
	if result, err := bazel_testing.BazelOutput("test", "//src:compare_results_test", "--test_output=errors"); err != nil {
		t.Logf("%s", result)
		t.Fatal(err)
	}
}
