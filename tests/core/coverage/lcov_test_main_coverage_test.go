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

package lcov_test_main_coverage_test

import (
	"io/ioutil"
	"path/filepath"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- src/BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "lib",
    srcs = ["lib.go"],
    importpath = "example.com/lib",
)

go_test(
    name = "lib_test",
    srcs = ["lib_test.go"],
    deps = [":lib"],
)
-- src/lib.go --
package lib

func HelloFromLib(informal bool) string {
	if informal {
		return "Hey there, lib!"
	} else {
		return "Good morning, lib!"
	}
}
-- src/lib_test.go --
package lib_test

import (
	"strings"
	"testing"
	"os"

	"example.com/lib"
)

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}

func TestLib(t *testing.T) {
	if !strings.Contains(lib.HelloFromLib(false), "lib!") {
		t.Error("Expected 'lib!' in the output")
	}
}
`,
	})
}

func TestLcovCoverageWithTestMain(t *testing.T) {
	if err := bazel_testing.RunBazel("coverage", "--combined_report=lcov", "//src:lib_test"); err != nil {
		t.Fatal(err)
	}

	individualCoveragePath := filepath.FromSlash("bazel-testlogs/src/lib_test/coverage.dat")
	individualCoverageData, err := ioutil.ReadFile(individualCoveragePath)
	if err != nil {
		t.Fatal(err)
	}
	if string(individualCoverageData) != string(expectedIndividualCoverage) {
		t.Errorf(
			"%s: expected content:\n\n%s\nactual content:\n\n%s",
			individualCoveragePath,
			expectedIndividualCoverage,
			string(individualCoverageData),
		)
	}

	combinedCoveragePath := filepath.FromSlash("bazel-out/_coverage/_coverage_report.dat")
	combinedCoverageData, err := ioutil.ReadFile(combinedCoveragePath)
	if err != nil {
		t.Fatal(err)
	}
	for _, include := range []string{
		"SF:src/lib.go\n",
	} {
		if !strings.Contains(string(combinedCoverageData), include) {
			t.Errorf("%s: does not contain %q\n", combinedCoverageData, include)
		}
	}
}

const expectedIndividualCoverage = `SF:src/lib.go
FNF:0
FNH:0
DA:3,1
DA:4,1
DA:5,0
DA:6,1
DA:7,1
DA:8,1
LH:5
LF:6
end_of_record
`
