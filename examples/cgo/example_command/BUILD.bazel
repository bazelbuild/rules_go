package(
    default_visibility = ["//visibility:public"],
)

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "example_command",
    srcs = ["main.go"],
    deps = [
        "//examples/cgo:go_default_library",
    ],
)

sh_test(
    name = "example_command_test",
    size = "small",
    srcs = ["example_command_test.sh"],
    data = [":example_command"],
)
