package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_binary", "go_library")

go_binary(
    name = "stamped_bin",
    srcs = ["main.go"],
    linkstamp = "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp",
    deps = [
        ":stamp",
    ],
)

go_library(
    name = "stamp",
    srcs = ["stamp.go"],
)
