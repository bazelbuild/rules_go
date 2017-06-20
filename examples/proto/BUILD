load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["gs.go"],
    visibility = ["//visibility:public"],
    deps = [
        "//examples/proto/gostyle:go_default_library",
        "//examples/proto/lib:lib_proto",
    ],
)

go_test(
    name = "proto_test",
    srcs = ["proto_test.go"],
    deps = ["//examples/proto/lib:lib_proto"],
    size = "small",
)
