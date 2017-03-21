load("//go:def.bzl", "cgo_library", "go_binary", "go_library", "go_test")

go_test(
    name = "go_default_test",
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
    srcs = ["empty.go"],
    data = ["go_data.txt"],
    library = ":cgo_lib",
)

cgo_library(
    name = "cgo_lib",
    srcs = ["empty_cgo.go"],
    cdeps = [":c_lib"],
    data = ["cgo_data.txt"],
)

cc_library(
    name = "c_lib",
    srcs = [],
    data = ["c_data.txt"],
)
