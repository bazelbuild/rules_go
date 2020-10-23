# This test checks that go_binary and go_test produce a single output file.
# See documentation in single_output_test.bzl.

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_test")
load("@io_bazel_rules_go//go/private/tools:single_output_test.bzl", "single_output_test")

single_output_test(
    name = "binary_single_output_test",
    size = "small",
    dep = ":bin",
)

go_binary(
    name = "bin",
    srcs = ["bin.go"],
    tags = ["manual"],
)

single_output_test(
    name = "test_single_output_test",
    size = "small",
    dep = ":test",
)

go_test(
    name = "test",
    size = "small",
    srcs = ["test.go"],
    tags = ["manual"],
)
