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

package ios_select_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "use_ios_lib",
    importpath = "github.com/bazelbuild/rules_go/tests/core/cross/use_ios_lib",
    deps = select({
        ":is_osx": [":ios_lib"],
        "//conditions:default": [],
    }),
)

config_setting(
    name = "is_osx",
    constraint_values = ["@platforms//os:osx"],
)

go_library(
    name = "ios_lib",
    srcs = select({
        "@io_bazel_rules_go//go/platform:darwin": ["ios_good.go"],
        "@io_bazel_rules_go//go/platform:ios": ["ios_good.go"],
        "//conditions:default": ["ios_bad.go"],
    }),
    importpath = "github.com/bazelbuild/rules_go/tests/core/cross/ios_lib",
)

-- ios_good.go --
package ios_lib

-- ios_bad.go --
donotbuild
`,
	})
}

func Test(t *testing.T) {
	if err := bazel_testing.RunBazel("build", "--platforms=@io_bazel_rules_go//go/toolchain:ios_amd64", ":ios_lib"); err != nil {
		t.Fatal(err)
	}
}
