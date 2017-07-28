/* Copyright 2017 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package merger

import (
	"testing"

	bf "github.com/bazelbuild/buildtools/build"
)

func TestFixFile(t *testing.T) {
	for _, tc := range []struct {
		desc, old, want string
	}{
		// fixLoads tests
		{
			desc: "add and remove loaded symbols",
			old: `load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(name = "go_default_library")

go_binary(name = "cmd")
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(name = "go_default_library")

go_binary(name = "cmd")
`,
		}, {
			desc: "consolidate load statements",
			old: `load("@io_bazel_rules_go//go:def.bzl", "go_library")
load("@io_bazel_rules_go//go:def.bzl", "go_library")
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_library(name = "go_default_library")

go_test(name = "go_default_test")
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(name = "go_default_library")

go_test(name = "go_default_test")
`,
		}, {
			desc: "new load statement",
			old: `go_library(
    name = "go_default_library",
)

go_embed_data(
    name = "data",
)
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)

go_embed_data(
    name = "data",
)
`,
		}, {
			desc: "fixLoad doesn't touch other symbols or loads",
			old: `load(
    "@io_bazel_rules_go//go:def.bzl",
    "go_embed_data",  # embed
    "go_test",
    foo = "go_binary",  # binary
)
load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_library(
    name = "go_default_library",
)
`,
			want: `load(
    "@io_bazel_rules_go//go:def.bzl",
    "go_embed_data",  # embed
    "go_library",
    foo = "go_binary",  # binary
)
load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_library(
    name = "go_default_library",
)
`,
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			oldFile, err := bf.Parse("old", []byte(tc.old))
			if err != nil {
				t.Fatalf("%s: parse error: %v", tc.desc, err)
			}
			fixedFile := FixFile(oldFile)
			if got := string(bf.Format(fixedFile)); got != tc.want {
				t.Fatalf("%s: got %s; want %s", tc.desc, got, tc.want)
			}
		})
	}
}
