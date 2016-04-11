package(default_visibility = ["//visibility:public"])

load("//go:def.bzl", "go_library", "go_binary", "go_test")

go_library(
    name = "extract_package_lib",
    srcs = ["extract.go"],
    visibility = ["//visibility:private"],
)

go_binary(
    name = "extract_package",
    library = ":extract_package_lib",
)

go_test(
    name = "extract_package_test",
    srcs = ["extract_test.go"],
    library = ":extract_package_lib",
)
