package(default_visibility = ["//visibility:public"])

load("//go:def.bzl", "go_library", "cgo_genrule")

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
