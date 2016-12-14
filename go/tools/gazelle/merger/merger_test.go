package merger

import (
	"io"
	"io/ioutil"
	"os"
	"testing"

	bzl "github.com/bazelbuild/buildifier/core"
)

const (
	oldData = `
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

	newData = `
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
	expected = `load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

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

	ignoreProto = `
load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "go_default_library",
    srcs = ["foo.proto"],
    deps = ["@com_github_golang_protobuf//ptypes/any:go_default_library"],
)
`
	pbGoGen = `
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["foo.pb.go"],
)

filegroup(
    name = "go_default_library_protos",
    srcs = ["foo.proto"],
)
`
)

type parseTest struct {
	previous, gazelle, want string
}

func TestMergeWithExisting(t *testing.T) {
	for _, test := range []parseTest{
		{oldData, newData, expected},
		{ignoreProto, pbGoGen, ignoreProto[1:]},
	} {
		tmp, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "")
		if err != nil {
			t.Fatal(err)
		}
		defer os.Remove(tmp.Name())
		if _, err := io.WriteString(tmp, test.previous); err != nil {
			t.Fatal(err)
		}
		if err := tmp.Close(); err != nil {
			t.Fatal(err)
		}
		newF, err := bzl.Parse(tmp.Name(), []byte(test.gazelle))
		if err != nil {
			t.Fatal(err)
		}
		afterF, err := MergeWithExisting(newF)
		if err != nil {
			t.Fatal(err)
		}
		if s := string(bzl.Format(afterF)); s != test.want {
			t.Errorf("bzl.Format, want %s; got %s", test.want, s)
		}
	}
}
