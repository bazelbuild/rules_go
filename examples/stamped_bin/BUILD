package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["main.go"],
    visibility = ["//visibility:private"],
    deps = ["//examples/stamped_bin/stamp:go_default_library"],
)

go_binary(
    name = "stamped_bin",
    library = ":go_default_library",
    visibility = ["//visibility:public"],
)
