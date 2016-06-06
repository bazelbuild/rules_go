package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_binary")

go_binary(
    name = "bin",
    srcs = ["bin.go"],
    deps = [
        "//examples/lib:go_default_library",
        "//examples/vendor/github.com/user/vendored:go_default_library",
    ],
    x_defs = {
        "main.buildTime": "2016/05/19 09:10am",
    },
)
