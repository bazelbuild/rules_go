package(
    default_visibility = ["//visibility:public"],
)

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "mycmd",
    srcs = ["mycmd.go"],
    deps = [
        "//examples/monobuild/lib1:go_default_library",
        "//examples/monobuild/lib2:go_default_library",
    ],
)
