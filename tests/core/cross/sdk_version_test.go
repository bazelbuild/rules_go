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

package go_download_sdk_test

import (
	"fmt"
	"strings"
	"testing"
	"text/template"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

type testcase struct {
	Name, SDKVersion, ExpectedVersion string
}

var testCases = []testcase{
	{
		Name:            "major_version",
		SDKVersion:      "1",
		ExpectedVersion: "go1.16",
	},
	{
		Name:            "minor_version",
		SDKVersion:      "1.16",
		ExpectedVersion: "go1.16",
	},
	{
		Name:            "patch_version",
		SDKVersion:      "1.16.0",
		ExpectedVersion: "go1.16",
	},
	{
		Name:            "1_17_minor_version",
		SDKVersion:      "1.17",
		ExpectedVersion: "go1.17",
	},
	{
		Name:            "1_17_patch_version",
		SDKVersion:      "1.17.1",
		ExpectedVersion: "go1.17.1",
	},
}

func TestMain(m *testing.M) {
	mainFilesTmpl := template.Must(template.New("").Parse(`
-- WORKSPACE --
local_repository(
    name = "io_bazel_rules_go",
    path = "../io_bazel_rules_go",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk", "go_rules_dependencies", "go_register_toolchains")

go_rules_dependencies()

go_download_sdk(
    name = "go_sdk",
    version = "1.16",
)
go_download_sdk(
    name = "go_sdk_1_17",
    version = "1.17",
)
go_download_sdk(
    name = "go_sdk_1_17_1",
    version = "1.17.1",
)
go_register_toolchains()
-- main.go --
package main

import (
  "fmt"
	"runtime"
)

func main() {
  fmt.Print(runtime.Version())
}
-- test.go --
package test

import (
  "runtime"
  "testing"
)

var WantVersion = ""

func TestVersion(t *testing.T) {
  gotVersion := runtime.Version()
  if WantVersion != gotVersion {
    t.Logf("wanted %s, got %s", WantVersion, gotVersion)
    t.Fail()
  }
}
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_cross_binary", "go_test", "go_cross_test")

go_binary(
  name = "print_version",
  srcs = ["main.go"],
)
{{range .TestCases}}
go_cross_binary(
  name = "{{.Name}}_binary",
  target = ":print_version",
  sdk_version = "{{.SDKVersion}}",
)

go_test(
  name = "{{.Name}}_test_w_env",
  srcs = ["test.go"],
  x_defs = {"WantVersion": "{{.ExpectedVersion}}"},
)
go_cross_test(
  name = "{{.Name}}_test",
  target = ":{{.Name}}_test_w_env",
  sdk_version = "{{.SDKVersion}}",
)
{{end}}
`))
  tmplValues := struct{
    TestCases []testcase
  }{
    TestCases: testCases,
  }
  mainFilesBuilder := &strings.Builder{}
  if err := mainFilesTmpl.Execute(mainFilesBuilder, tmplValues); err != nil {
    panic(err)
  }

  bazel_testing.TestMain(m, bazel_testing.Args{Main: mainFilesBuilder.String()})
}

func Test(t *testing.T) {
	for _, test := range testCases {
		t.Run(test.Name, func(t *testing.T) {
			output, err := bazel_testing.BazelOutput("run", fmt.Sprintf("//:%s_binary", test.Name))
			if err != nil {
				t.Fatal(err)
			}
			actualVersion := string(output)
			if actualVersion != test.ExpectedVersion {
				t.Fatal("actual", actualVersion, "vs expected", test.ExpectedVersion)
			}

      err = bazel_testing.RunBazel("test", fmt.Sprintf("//:%s_test", test.Name))
      if err != nil {
        t.Fatal(err)
      }
		})
	}
}
