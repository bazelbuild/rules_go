package(default_visibility = ["//visibility:public"])

load("//go:def.bzl", "go_library", "cgo_library")

go_library(
    name = "go_default_library",
    srcs = [
        "types.go",
    ],
    library = ":cgo_default_library",
)

cgo_library(
    name = "cgo_default_library",
    srcs = [
        "cgo_foo.go",
    ],
    skip_go_library = True,
)
