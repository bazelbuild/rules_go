package(
    default_visibility = ["//visibility:public"],
)

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "bin",
    srcs = ["bin.go"],
    x_defs = {
        "main.buildTime": "2016/05/19 09:10am",
    },
    deps = [
        "//examples/lib:go_default_library",
        "//examples/vendor/github.com/user/vendored:go_default_library",
    ],
)
