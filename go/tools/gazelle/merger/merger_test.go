package merger

import (
	"io"
	"io/ioutil"
	"os"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
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
	},
}

func TestMergeWithExisting(t *testing.T) {
	tmp, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "")
	if err != nil {
		t.Fatal(err)
	}
	if err := tmp.Close(); err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmp.Name())
	for _, tc := range testCases {
		if err := ioutil.WriteFile(tmp.Name(), []byte(tc.previous), 0755); err != nil {
			t.Fatalf("%s: %v", tc.desc, err)
		}
		newF, err := bzl.Parse("current", []byte(tc.current))
		if err != nil {
			t.Fatalf("%s: %v", tc.desc, err)
		}
		afterF, err := MergeWithExisting(newF, tmp.Name())
		if _, ok := err.(GazelleIgnoreError); ok {
			if !tc.ignore {
				t.Fatalf("%s: unexpected ignore: %v", tc.desc, err)
			}
			continue
		} else if err != nil {
			t.Fatalf("%s: %v", tc.desc, err)
		}
		if tc.ignore {
			t.Errorf("%s: expected ignore", tc.desc)
		}

		want := tc.expected
		if len(want) > 0 && want[0] == '\n' {
			want = want[1:]
		}

		if got := string(bzl.Format(afterF)); got != want {
			t.Errorf("%s: got %s; want %s", tc.desc, got, want)
		}
	}
}

func TestMergeWithExistingDifferentName(t *testing.T) {
	oldData := testCases[0].previous
	newData := testCases[0].current
	expected := testCases[0].expected
	if len(expected) > 0 && expected[0] == '\n' {
		expected = expected[1:]
	}

	tmp, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "BUILD")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmp.Name())
	if _, err := io.WriteString(tmp, oldData); err != nil {
		t.Fatal(err)
	}
	if err := tmp.Close(); err != nil {
		t.Fatal(err)
	}
	newTmp, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "BUILD.bazel")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(newTmp.Name())
	newF, err := bzl.Parse(newTmp.Name(), []byte(newData))
	if err != nil {
		t.Fatal(err)
	}
	afterF, err := MergeWithExisting(newF, tmp.Name())
	if err != nil {
		t.Error(err)
	}
	if s := string(bzl.Format(afterF)); s != expected {
		t.Errorf("got %s; want %s", s, expected)
	}
}
