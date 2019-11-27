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

package test_filter_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "filter_test",
    srcs = ["filter_test.go"],
)

-- filter_test.go --
package test_filter

import "testing"

func TestShouldPass(t *testing.T) {
}

func TestShouldFail(t *testing.T) {
	t.Fail()
}

`,
	})
}

func Test(t *testing.T) {
	if err := bazel_testing.RunBazel("test", "//:filter_test", "--test_filter=Pass"); err != nil {
		t.Fatal(err)
	}
}
