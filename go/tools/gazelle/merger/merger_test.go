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
	desc, previous, current, expected string
	ignore                            bool
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
    library = ":go_default_library",
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
    library = ":go_default_library",
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
    library = ":go_default_library",
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
    deps = ["deleted"],
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
go_library(
    name = "go_default_library",
    srcs = [
        "a.go",  # preserve
        "b.go",  # comments
    ],
)
`,
		current: `
go_library(
    name = "go_default_library",
    srcs = ["a.go", "b.go"],
)
`,
		expected: `
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
    clinkopts = ["-lpng"],
)
`,
	},
}

func TestMergeWithExisting(t *testing.T) {
	for _, tc := range testCases {
		genFile, err := bf.Parse("current", []byte(tc.current))
		if err != nil {
			t.Errorf("%s: %v", tc.desc, err)
			continue
		}
		oldFile, err := bf.Parse("previous", []byte(tc.previous))
		if err != nil {
			t.Errorf("%s: %v", tc.desc, err)
			continue
		}
		mergedFile := MergeWithExisting(genFile, oldFile)
		if mergedFile == nil {
			if !tc.ignore {
				t.Errorf("%s: got nil; want file", tc.desc)
			}
			continue
		}
		if mergedFile != nil && tc.ignore {
			t.Errorf("%s: got file; want nil", tc.desc)
			continue
		}

		want := tc.expected
		if len(want) > 0 && want[0] == '\n' {
			want = want[1:]
		}

		if got := string(bf.Format(mergedFile)); got != want {
			t.Errorf("%s: got %s; want %s", tc.desc, got, want)
		}
	}
}

func TestMergeWithExistingDifferentName(t *testing.T) {
	oldFile := &bf.File{Path: "BUILD"}
	genFile := &bf.File{Path: "BUILD.bazel"}
	mergedFile := MergeWithExisting(genFile, oldFile)
	if got, want := mergedFile.Path, oldFile.Path; got != want {
		t.Errorf("got %q; want %q", got, want)
	}
}
