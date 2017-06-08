load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_test")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["cgo_multi_dir_test.go"],
    library = ":cgo_default_library",
)

cgo_library(
    name = "cgo_default_library",
    srcs = [
        "bar/bar.go",
        "foo/foo.go",
    ],
)
