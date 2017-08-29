load("@io_bazel_rules_go//go/private:tools/go_tool_binary.bzl", "go_tool_binary")
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_tool_binary(
    name = "extract_package",
    srcs = ["extract.go"],
    visibility = ["//visibility:public"],
)

go_test(
    name = "extract_package_test",
    size = "small",
    srcs = [
        "extract.go",
        "extract_test.go",
    ],
)
