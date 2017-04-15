load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["bazel.go"],
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    srcs = ["bazel_test.go"],
    data = [
        "README.md",
    ],
    library = ":go_default_library",
)
