load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

go_library(
    name = "unsafe_srcs_lib",
    srcs = ["unsafe.go"],
    gc_goopts = ["-u"],
    tags = ["manual"],
)

go_library(
    name = "unsafe_library_lib",
    library = ":unsafe_srcs_lib",
    tags = ["manual"],
)

go_binary(
    name = "unsafe_srcs_bin",
    srcs = [
        "empty_main.go",
        "unsafe.go",
    ],
    gc_goopts = ["-u"],
    tags = ["manual"],
)

go_binary(
    name = "unsafe_library_bin",
    srcs = ["empty_main.go"],
    library = ":unsafe_srcs_lib",
    tags = ["manual"],
)

go_test(
    name = "unsafe_srcs_test",
    size = "small",
    srcs = [
        "empty_test.go",
        "unsafe.go",
    ],
    gc_goopts = ["-u"],
    tags = ["manual"],
)

go_test(
    name = "unsafe_library_test",
    size = "small",
    library = ":unsafe_srcs_lib",
    tags = ["manual"],
)

go_library(
    name = "unsafe_cgo_lib",
    srcs = ["unsafe_cgo.go"],
    cgo = True,
    gc_goopts = ["-u"],
    tags = ["manual"],
)

go_library(
    name = "unsafe_cgo_client_lib",
    library = ":unsafe_cgo_lib",
    tags = ["manual"],
)

go_binary(
    name = "unsafe_link_bin",
    srcs = [
        "empty_main.go",
        "unsafe.go",
    ],
    gc_linkopts = ["-u"],
    tags = ["manual"],
)

go_test(
    name = "unsafe_link_test",
    size = "small",
    srcs = [
        "empty_test.go",
        "unsafe.go",
    ],
    gc_linkopts = ["-u"],
    tags = ["manual"],
)
