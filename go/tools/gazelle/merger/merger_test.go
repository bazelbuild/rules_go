package merger

import (
	"io"
	"io/ioutil"
	"os"
	"testing"

	bzl "github.com/bazelbuild/buildifier/build"
)

const oldData = `
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test", "go_binary")

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
`

const newData = `
load("@io_bazel_rules_go//go:def.bzl", "go_test", "go_library")

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
`

// should fix
// * updated srcs from new
// * data and size preserved from old
// * load stmt fixed to those in use and sorted
const expected = `load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

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
        "parse_test.go",
        "print_test.go",
        "gen_test.go",  # keep
    ],
    data = glob(["testdata/*"]),
    library = ":go_default_library",
)
`

const ignoreTop = `# gazelle:ignore

load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "lex.go",
        "print.go",
    ],
)
`

const ignoreBefore = `# gazelle:ignore
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")
`

const ignoreAfterLast = `
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")
# gazelle:ignore`

type testCase struct {
	previous, current, expected string
	ignore                      bool
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
	for _, tc := range []testCase{
		{oldData, newData, expected, false},
		{ignoreTop, newData, "", true},
		{ignoreBefore, newData, "", true},
		{ignoreAfterLast, newData, "", true},
	} {
		if err := ioutil.WriteFile(tmp.Name(), []byte(tc.previous), 0755); err != nil {
			t.Fatal(err)
		}
		newF, err := bzl.Parse(tmp.Name(), []byte(tc.current))
		if err != nil {
			t.Fatal(err)
		}
		afterF, err := MergeWithExisting(newF, tmp.Name())
		if _, ok := err.(GazelleIgnoreError); ok {
			if !tc.ignore {
				t.Fatalf("unexpected ignore: %v", err)
			}
			continue
		} else if err != nil {
			t.Fatal(err)
		}
		if tc.ignore {
			t.Error("expected ignore")
		}
		if s := string(bzl.Format(afterF)); s != tc.expected {
			t.Errorf("bzl.Format, want %s; got %s", tc.expected, s)
		}
	}
}

func TestMergeWithExistingDifferentName(t *testing.T) {
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
		t.Errorf("bzl.Format, want %s; got %s", expected, s)
	}
}
