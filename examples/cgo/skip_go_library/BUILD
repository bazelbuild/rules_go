package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_go//go:def.bzl", "go_library", "cgo_genrule")

go_library(
    name = "go_default_library",
    srcs = [
        "types.go",
    ],
    library = ":cgo_codegen",
)

cgo_genrule(
    name = "cgo_codegen",
    srcs = [
        "cgo_foo.go",
    ],
)
