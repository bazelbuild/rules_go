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

package embedsrcs_errors

import (
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "invalid",
    srcs = ["invalid.go"],
    importpath = "invalid",
)

go_library(
    name = "none",
    srcs = ["none.go"],
    importpath = "none",
)

go_library(
    name = "multi_dir",
    srcs = [
        "a.go",
        "b/b.go",
    ],
    embedsrcs = [
        "a.txt",
        "b/b.txt",
    ],
    importpath = "multi_dir",
)

go_library(
    name = "embeds_vcs_dir",
    srcs = ["c/c.go"],
    embedsrcs = ["c/.bzr/c.txt"],
    importpath = "embeds_vcs_dir",
)
-- invalid.go --
package invalid

import _ "embed"

//go:embed ..
var x string
-- none.go --
package none

import _ "embed"

//go:embed none
var x string
-- a.go --
package a

import _ "embed"

//go:embed a.txt
var x string
-- a.txt --
-- b/b.go --
package a

import _ "embed"

//go:embed b.txt
var y string
-- b/b.txt --
-- c/c.go --
package a

import _ "embed"

//go:embed .bzr
var z string
-- c/.bzr/c.txt --
`,
	})
}

func Test(t *testing.T) {
	for _, test := range []struct {
		desc, target, want string
	}{
		{
			desc:   "invalid",
			target: "//:invalid",
			want:   "invalid pattern syntax",
		},
		{
			desc:   "none",
			target: "//:none",
			want:   "could not embed none: no matching files found",
		},
		{
			desc:   "multi_dir",
			target: "//:multi_dir",
			want:   "source files with //go:embed should be in same directory",
		},
		{
			desc:   "embeds_vcs_dir",
			target: "//:embeds_vcs_dir",
			want:   "could not embed .bzr: cannot embed directory .bzr: invalid name .bzr",
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			err := bazel_testing.RunBazel("build", test.target)
			if err == nil {
				t.Fatalf("expected error matching %q", test.want)
			}
			if errMsg := err.Error(); !strings.Contains(errMsg, test.want) {
				t.Fatalf("expected error matching %q; got %v", test.want, errMsg)
			}
		})
	}
}
