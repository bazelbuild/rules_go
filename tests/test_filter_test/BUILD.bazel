load("@io_bazel_rules_go//go:def.bzl", "go_prefix", "go_test")
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

go_prefix("github.com/bazelbuild/rules_go/tests/test_filter_test")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["test_filter_test.go"],
    tags = ["manual"],
)

bazel_test(
    name = "test_filter_test",
    args = ["--test_filter=Pass"],
    command = "test",
    target = "//:go_default_test",
)
