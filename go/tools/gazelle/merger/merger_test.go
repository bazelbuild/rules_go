/* Copyright 2016 The Bazel Authors. All rights reserved.

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

// should fix
// * updated srcs from new
// * data and size preserved from old
// * load stmt fixed to those in use and sorted

type testCase struct {
	desc, previous, current, empty, expected string
	ignore                                   bool
}

var testCases = []testCase{
	{
		desc: "basic functionality",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_prefix", "go_test")

go_prefix("github.com/jr_hacker/tools")

go_library(
    name = "go_default_library",
    srcs = glob(["*.go"]),
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = [
        "gen_test.go",  # keep
        "parse_test.go",
    ],
    data = glob(["testdata/*"]),
    embed = [":go_default_library"],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_test", "go_library")

go_prefix("")

go_library(
    name = "go_default_library",
    srcs = [
        "lex.go",
        "print.go",
    ],
)

go_test(
    name = "go_default_test",
    srcs = [
        "parse_test.go",
        "print_test.go",
    ],
    embed = [":go_default_library"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_prefix", "go_test")

go_prefix("github.com/jr_hacker/tools")

go_library(
    name = "go_default_library",
    srcs = [
        "lex.go",
        "print.go",
    ],
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = [
        "gen_test.go",  # keep
        "parse_test.go",
        "print_test.go",
    ],
    data = glob(["testdata/*"]),
    embed = [":go_default_library"],
)
`},
	{
		desc: "ignore top",
		previous: `# gazelle:ignore

load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "lex.go",
        "print.go",
    ],
)
`,
		ignore: true,
	}, {
		desc: "ignore before first",
		previous: `
# gazelle:ignore
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")
`,
		ignore: true,
	}, {
		desc: "ignore after last",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")
# gazelle:ignore`,
		ignore: true,
	}, {
		desc: "merge dicts",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "darwin_amd64": [
            "foo_darwin_amd64.go", # keep
            "bar_darwin_amd64.go",
        ],
        "linux_arm": [
            "foo_linux_arm.go", # keep
            "bar_linux_arm.go",
        ],
    }),
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": ["baz_linux_arm.go"],
        "darwin_amd64": ["baz_darwin_amd64.go"],
        "//conditions:default": [],
    }),
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "darwin_amd64": [
            "foo_darwin_amd64.go",  # keep
            "baz_darwin_amd64.go",
        ],
        "linux_arm": [
            "foo_linux_arm.go",  # keep
            "baz_linux_arm.go",
        ],
        "//conditions:default": [],
    }),
)
`,
	}, {
		desc: "merge old dict with gen list",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": [
            "foo_linux_arm.go", # keep
            "bar_linux_arm.go", # keep
        ],
        "darwin_amd64": [
            "bar_darwin_amd64.go",
        ],
    }),
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["baz.go"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "baz.go",
    ] + select({
        "linux_arm": [
            "foo_linux_arm.go",  # keep
            "bar_linux_arm.go",  # keep
        ],
    }),
)
`,
	}, {
		desc: "merge old list with gen dict",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "foo.go", # keep
        "bar.go", # keep
    ],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": [
            "foo_linux_arm.go",
            "bar_linux_arm.go",
        ],
        "darwin_amd64": [
            "bar_darwin_amd64.go",
        ],
        "//conditions:default": [],
    }),
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "foo.go",  # keep
        "bar.go",  # keep
    ] + select({
        "linux_arm": [
            "foo_linux_arm.go",
            "bar_linux_arm.go",
        ],
        "darwin_amd64": [
            "bar_darwin_amd64.go",
        ],
        "//conditions:default": [],
    }),
)
`,
	}, {
		desc: "merge old list and dict with gen list and dict",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "foo.go",  # keep
        "bar.go",
    ] + select({
        "linux_arm": [
            "foo_linux_arm.go",  # keep
        ],
        "//conditions:default": [],
    }),
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["baz.go"] + select({
        "linux_arm": ["bar_linux_arm.go"],
        "darwin_amd64": ["foo_darwin_amd64.go"],
        "//conditions:default": [],
    }),
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "foo.go",  # keep
        "baz.go",
    ] + select({
        "darwin_amd64": ["foo_darwin_amd64.go"],
        "linux_arm": [
            "foo_linux_arm.go",  # keep
            "bar_linux_arm.go",
        ],
        "//conditions:default": [],
    }),
)
`,
	}, {
		desc: "delete empty list",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["deleted.go"],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": ["foo_linux_arm.go"],
    }),
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": ["foo_linux_arm.go"],
    }),
)
`,
	}, {
		desc: "delete empty dict",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "linux_arm": ["foo_linux_arm.go"],
        "//conditions:default": [],
    }),
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
)
`,
	}, {
		desc: "delete empty attr",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
    embed = ["deleted"],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
)
`,
	}, {
		desc: "merge comments",
		previous: `
# load
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# rule
go_library(
    # unmerged attr
    name = "go_default_library",
    # merged attr
    srcs = ["foo.go"],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.go"],
)
`,
		expected: `
# load
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# rule
go_library(
    # unmerged attr
    name = "go_default_library",
    # merged attr
    srcs = ["foo.go"],
)
`,
	}, {
		desc: "preserve comments",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "a.go",  # preserve
        "b.go",  # comments
    ],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["a.go", "b.go"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "a.go",  # preserve
        "b.go",  # comments
    ],
)
`,
	}, {
		desc: "merge copts and clinkopts",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

cgo_library(
    name = "cgo_default_library",
    copts = [
        "-O0",
        "-g",  # keep
    ],
    clinkopts = [
        "-lX11",
    ],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

cgo_library(
    name = "cgo_default_library",
    copts = [
        "-O2",
    ],
    clinkopts = [
        "-lpng",
    ],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "cgo_library")

cgo_library(
    name = "cgo_default_library",
    copts = [
        "-g",  # keep
        "-O2",
    ],
    clinkopts = [
        "-lpng",
    ],
)
`,
	}, {
		desc: "keep scalar attr",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    embed = [":lib"],  # keep
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    embed = [":lib"],  # keep
)
`,
	}, {
		desc: "don't delete list with keep",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "one.go",  # keep
    ],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "one.go",  # keep
    ],
)
`,
	}, {
		desc: "keep list multiline",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "one.go",  # keep
        "two.go",
    ],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "one.go",  # keep
    ],
)
`,
	}, {
		desc: "keep dict list multiline",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "darwin_amd64": [
            "one_darwin.go",  # keep
        ],
        "linux_arm": [
            "one_linux.go",  # keep
            "two_linux.go",
        ],
    }),
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = select({
        "darwin_amd64": [
            "one_darwin.go",  # keep
        ],
        "linux_arm": [
            "one_linux.go",  # keep
        ],
    }),
)
`,
	}, {
		desc: "keep prevents delete",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# keep
go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)
`,
		empty: `
go_library(name = "go_default_library")
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# keep
go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)
`,
	}, {
		desc: "keep prevents merge",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# keep
go_library(
    name = "go_default_library",
    srcs = ["old.go"],
)
`,
		current: `
go_library(
    name = "go_default_library",
    srcs = ["new.go"],
)
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

# keep
go_library(
    name = "go_default_library",
    srcs = ["old.go"],
)
`,
	}, {
		desc: "delete empty rule",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)

go_binary(
    name = "old",
    srcs = ["bin.go"],
    embed = [":go_default_library"],
)
`,
		current: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)
`,
		empty: `
go_binary(name = "old")
`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)
`,
	}, {
		desc: "don't delete kept rule",
		previous: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "lib.go",  # keep
    ],
)
`,
		empty: `go_library(name = "go_default_library")`,
		expected: `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "lib.go",  # keep
    ],
)
`,
	},
}

func TestMergeFile(t *testing.T) {
	for _, tc := range testCases {
		t.Run(tc.desc, func(t *testing.T) {
			genFile, err := bf.Parse("current", []byte(tc.current))
			if err != nil {
				t.Fatalf("%s: %v", tc.desc, err)
			}
			oldFile, err := bf.Parse("previous", []byte(tc.previous))
			if err != nil {
				t.Fatalf("%s: %v", tc.desc, err)
			}
			emptyFile, err := bf.Parse("empty", []byte(tc.empty))
			if err != nil {
				t.Fatalf("%s: %v", tc.desc, err)
			}
			mergedFile, _ := MergeFile(genFile.Stmt, emptyFile.Stmt, oldFile, MergeableGeneratedAttrs)
			if mergedFile == nil {
				if !tc.ignore {
					t.Errorf("%s: got nil; want file", tc.desc)
				}
				return
			}
			if mergedFile != nil && tc.ignore {
				t.Fatalf("%s: got file; want nil", tc.desc)
			}
			mergedFile = FixLoads(mergedFile)

			want := tc.expected
			if len(want) > 0 && want[0] == '\n' {
				want = want[1:]
			}

			if got := string(bf.Format(mergedFile)); got != want {
				t.Fatalf("%s: got %s; want %s", tc.desc, got, want)
			}
		})
	}
}
