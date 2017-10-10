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
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

type fixTestCase struct {
	desc, old, want string
}

func TestFixFile(t *testing.T) {
	for _, tc := range []fixTestCase{
		// squashCgoLibrary tests
		{
			desc: "no cgo_library",
			old: `load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
		},
		{
			desc: "non-default cgo_library not removed",
			old: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

cgo_library(
    name = "something_else",
)
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

cgo_library(
    name = "something_else",
)
`,
		},
		{
			desc: "unlinked cgo_library removed",
			old: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_library")

go_library(
    name = "go_default_library",
    library = ":something_else",
)

cgo_library(
    name = "cgo_default_library",
)
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_library")

go_library(
    name = "go_default_library",
    cgo = True,
)
`,
		},
		{
			desc: "cgo_library replaced with go_library",
			old: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

# before comment
cgo_library(
    name = "cgo_default_library",
    cdeps = ["cdeps"],
    clinkopts = ["clinkopts"],
    copts = ["copts"],
    data = ["data"],
    deps = ["deps"],
    gc_goopts = ["gc_goopts"],
    srcs = [
        "foo.go"  # keep
    ],
    visibility = ["//visibility:private"],    
)
# after comment
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

# before comment
go_library(
    name = "go_default_library",
    visibility = ["//visibility:private"],
    cgo = True,
    cdeps = ["cdeps"],
    clinkopts = ["clinkopts"],
    copts = ["copts"],
    data = ["data"],
    deps = ["deps"],
    gc_goopts = ["gc_goopts"],
    srcs = [
        "foo.go",  # keep
    ],
)
# after comment
`,
		}, {
			desc: "cgo_library merged with go_library",
			old: `load("@io_bazel_rules_go//go:def.bzl", "go_library")

# before go_library
go_library(
    name = "go_default_library",
    srcs = ["pure.go"],
    deps = ["pure_deps"],
    data = ["pure_data"],
    gc_goopts = ["pure_gc_goopts"],
    library = ":cgo_default_library",
    cgo = False,
)
# after go_library

# before cgo_library
cgo_library(
    name = "cgo_default_library",
    srcs = ["cgo.go"],
    deps = ["cgo_deps"],
    data = ["cgo_data"],
    gc_goopts = ["cgo_gc_goopts"],
    copts = ["copts"],
    cdeps = ["cdeps"],
)
# after cgo_library
`,
			want: `load("@io_bazel_rules_go//go:def.bzl", "go_library")

# before go_library
# before cgo_library
go_library(
    name = "go_default_library",
    srcs = [
        "pure.go",
        "cgo.go",
    ],
    deps = [
        "pure_deps",
        "cgo_deps",
    ],
    data = [
        "pure_data",
        "cgo_data",
    ],
    gc_goopts = [
        "pure_gc_goopts",
        "cgo_gc_goopts",
    ],
    cgo = True,
    cdeps = ["cdeps"],
    copts = ["copts"],
)
# after go_library
# after cgo_library
`,
		},
		// fixLegacyProto tests
		{
			desc: "current proto preserved",
			old: `load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

go_proto_library(
    name = "foo_go_proto",
    proto = ":foo_proto",
)
`,
			want: `load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

go_proto_library(
    name = "foo_go_proto",
    proto = ":foo_proto",
)
`,
		},
		{
			desc: "load and proto removed",
			old: `load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "go_default_library_protos",
    srcs = ["foo.proto"],
    visibility = ["//visibility:private"],
)
`,
			want: "",
		},
		{
			desc: "proto filegroup removed",
			old: `filegroup(
    name = "go_default_library_protos",
    srcs = ["foo.proto"],
)

go_proto_library(name = "foo_proto")
`,
			want: `go_proto_library(name = "foo_proto")
`,
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			fix := func(f *bf.File) *bf.File {
				return FixFile(&config.Config{}, f)
			}
			testFix(t, tc, fix)
		})
	}
}

func TestFixLoads(t *testing.T) {
	for _, tc := range []fixTestCase{
		{
			desc: "empty file",
			old:  "",
			want: "",
		}, {
			desc: "non-Go file",
			old: `load("@io_bazel_rules_intercal//intercal:def.bzl", "intercal_library")

intercal_library(
    name = "intercal_default_library",
    srcs = ["foo.ic"],
)
`,
			want: `load("@io_bazel_rules_intercal//intercal:def.bzl", "intercal_library")

intercal_library(
    name = "intercal_default_library",
    srcs = ["foo.ic"],
)
`,
		}, {
			desc: "empty Go load",
			old: `load("@io_bazel_rules_go//go:def.bzl")
`,
			want: "",
		}, {
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
			desc: "proto symbols",
			old: `go_proto_library(
    name = "foo_proto",
)

go_grpc_library(
    name = "bar_proto",
)
`,
			want: `load("@io_bazel_rules_go//proto:def.bzl", "go_grpc_library", "go_proto_library")

go_proto_library(
    name = "foo_proto",
)

go_grpc_library(
    name = "bar_proto",
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
		}, {
			desc: "fixLoad doesn't touch loads from other files",
			old: `load(
    "@com_github_pubref_rules_protobuf//go:rules.bzl",
    "go_proto_library",
    go_grpc_library = "go_proto_library",
)

go_proto_library(
    name = "foo_go_proto",
)

grpc_proto_library(
    name = "bar_go_proto",
)
`,
			want: `load(
    "@com_github_pubref_rules_protobuf//go:rules.bzl",
    "go_proto_library",
    go_grpc_library = "go_proto_library",
)

go_proto_library(
    name = "foo_go_proto",
)

grpc_proto_library(
    name = "bar_go_proto",
)
`,
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			testFix(t, tc, FixLoads)
		})
	}
}

func testFix(t *testing.T, tc fixTestCase, fix func(*bf.File) *bf.File) {
	oldFile, err := bf.Parse("old", []byte(tc.old))
	if err != nil {
		t.Fatalf("%s: parse error: %v", tc.desc, err)
	}
	fixedFile := fix(oldFile)
	if got := string(bf.Format(fixedFile)); got != tc.want {
		t.Fatalf("%s: got %s; want %s", tc.desc, got, tc.want)
	}
}
