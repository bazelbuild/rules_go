load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["cgo_multi_dir_test.go"],
    library = ":go_default_library",
)

go_library(
    name = "go_default_library",
    srcs = [
        "bar/bar.go",
        "foo/foo.go",
    ],
    cgo = True,
)
