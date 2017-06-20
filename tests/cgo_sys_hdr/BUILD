load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_test")

cgo_library(
    name = "cgo_default_library",
    srcs = [
        "foo.go",
        "sub/foo.h",
    ],
)

go_test(
    name = "go_default_test",
    srcs = ["foo_test.go"],
    library = ":cgo_default_library",
    size = "small",
)
