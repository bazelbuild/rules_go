load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

package_group(
    name = "vis",
    packages = [
        "//...",
    ],
)

go_library(
    name = "foo",
    srcs = ["foo.go"],
    visibility = [":vis"],
    importpath = "github.com/bazelbuild/rules_go/test/foo",
)
