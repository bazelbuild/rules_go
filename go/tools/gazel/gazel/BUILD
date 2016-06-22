load("@io_bazel_rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "gazel",
    srcs = ["main.go"],
    deps = [
        "@io_bazel_buildifier//core:go_default_library",
        "//go/tools/gazel/generator:go_default_library",
    ],
)
