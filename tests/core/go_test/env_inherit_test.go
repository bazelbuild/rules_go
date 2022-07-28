// Copyright 2021 The Bazel Authors. All rights reserved.
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

package env_inherit_test

import (
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- src/BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")
go_test(
    name = "main",
	srcs = ["env_inherit.go"],
	env_inherit = ["INHERITEDVAR"],
)
-- src/env_inherit.go --
package env_inherit_test

import (
	"os"
	"testing"
)

func TestInherit(t *testing.T) {
	v := os.Getenv("INHERITEDVAR")
	if v != "b" {
		t.Fatalf("INHERITEDVAR was not equal to b")
	}
}
`,

		SetUp: func() error {
			os.Setenv("INHERITEDVAR", "b")
			return nil
		},
	})
}

func TestInheritedEnvVar(t *testing.T) {
	if err := bazel_testing.RunBazel("test", "//src:main"); err != nil {
		t.Fatal(err)
	}
}
