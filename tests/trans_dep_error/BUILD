load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
    deps = [":a"],
    tags = ["manual"],
)

go_library(
    name = "a",
    srcs = ["a.go"],
    deps = [":b"],
)

go_library(
    name = "b",
    srcs = ["b.go"],
)
