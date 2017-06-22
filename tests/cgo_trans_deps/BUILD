load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["cgo_lib.go"],
    deps = ["//tests/cgo_trans_deps/dep:go_default_library"],
    cgo = True,
)

go_test(
    name = "go_default_test",
    srcs = ["cgo_test.go"],
    library = ":go_default_library",
    size = "small",
)
