load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_binary", "go_library", "go_test")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["transitive_data_test.go"],
    args = [
        "go_data.txt",
        "cgo_data.txt",
        "c_data.txt",
    ],
    deps = [":go_lib"],
)

go_library(
    name = "go_lib",
    srcs = [
        "empty.go",
        "empty_cgo.go",
    ],
    cdeps = [":c_lib"],
    cgo = True,
    data = [
        "cgo_data.txt",
        "go_data.txt",
    ],
)

cc_library(
    name = "c_lib",
    srcs = [],
    data = ["c_data.txt"],
)
