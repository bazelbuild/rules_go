load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

bazel_test(
    name = "no_prefix",
    command = "build",
    target = "//:go_default_library //:go_default_xtest //:cmd",
)

go_library(
    name = "go_default_library",
    srcs = ["no_prefix.go"],
    importpath = "github.com/bazelbuild/rules_go/tests/no_prefix",
)

go_test(
    name = "go_default_xtest",
    srcs = ["no_prefix_test.go"],
    importpath = "github.com/bazelbuild/rules_go/tests/no_prefix_test",
    deps = [":go_default_library"],
)

go_binary(
    name = "cmd",
    srcs = ["cmd.go"],
    importpath = "github.com/bazelbuild/rules_go/tests/no_prefix/cmd",
    deps = [":go_default_library"],
)
