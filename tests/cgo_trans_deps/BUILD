load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_library", "go_test")

cgo_library(
    name = "cgo_default_library",
    srcs = ["cgo_lib.go"],
    deps = ["//tests/cgo_trans_deps/dep:go_default_library"],
)

go_library(
    name = "go_default_library",
    library = ":cgo_default_library",
)

go_test(
    name = "go_default_test",
    srcs = ["cgo_test.go"],
    library = ":go_default_library",
)
