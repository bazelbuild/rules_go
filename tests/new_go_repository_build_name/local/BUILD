load("@io_bazel_rules_go//go:def.bzl", "go_prefix", "go_test")

go_prefix("local")

go_test(
    name = "go_default_test",
    srcs = ["local_test.go"],
    tags = ["manual"],
    deps = ["@remote//build:go_default_library"],
    size = "small",
)
