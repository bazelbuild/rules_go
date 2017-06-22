load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_binary", "go_library", "go_test")

go_test(
    name = "go_default_test",
    srcs = ["transitive_data_test.go"],
    args = [
        "go_data.txt",
        "cgo_data.txt",
        "c_data.txt",
    ],
    deps = [":go_lib"],
    size = "small",
)

go_library(
    name = "go_lib",
    srcs = [
        "empty.go",
        "empty_cgo.go"
    ],
    data = [
        "go_data.txt",
        "cgo_data.txt",
    ],
    cdeps = [":c_lib"],
    cgo = True,
)

cc_library(
    name = "c_lib",
    srcs = [],
    data = ["c_data.txt"],
)
