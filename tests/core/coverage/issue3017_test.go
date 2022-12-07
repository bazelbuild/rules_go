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
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- fx.go --
package fx

import (
	_ "uber.com/internal"
)
-- fx_test.go --
package fx
-- internal/BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
    importpath = "uber.com/internal",
    visibility = ["//visibility:public"],
    deps = ["@io_bazel_rules_go//go/tools/coverdata"],
)

go_test(
    name = "go_default_test",
    srcs = ["lib_test.go"],
    embed = [":go_default_library"],
)
-- internal/lib.go --
package internal

import _ "github.com/bazelbuild/rules_go/go/tools/coverdata"
-- internal/lib_test.go --
package internal
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["fx.go"],
    importpath = "code.uber.internal/devexp/code-coverage/cmd/fx",
    visibility = ["//visibility:private"],
    deps = ["//internal:go_default_library"],
)

go_test(
    name = "go_default_test",
    srcs = ["fx_test.go"],
    embed = [":go_default_library"],
)
`,
	})
}

func TestIssue3017(t *testing.T) {
	if err := bazel_testing.RunBazel("coverage", "//:go_default_test"); err != nil {
		t.Fatal(err)
	}
}
