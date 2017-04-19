# This test checks that go_binary and go_test produce a single output file.
# See documentation in single_output_test.bzl.

load("//go:def.bzl", "go_binary", "go_test")
load("//go/private:single_output_test.bzl", "single_output_test")

single_output_test(
    name = "binary_single_output_test",
    dep = ":bin",
)

go_binary(
    name = "bin",
    srcs = ["bin.go"],
    tags = ["manual"],
)

single_output_test(
    name = "test_single_output_test",
    dep = ":test",
)

go_test(
    name = "test",
    srcs = ["test.go"],
    tags = ["manual"],
)
