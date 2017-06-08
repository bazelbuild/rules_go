load("@io_bazel_rules_go//go/private:go_tool_binary.bzl", "go_tool_binary")
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "filter_test",
    srcs = [
        "filter.go",
        "filter_test.go",
    ],
)

go_tool_binary(
    name = "asm",
    srcs = [
        "asm.go",
        "filter.go",
    ],
    visibility = ["//visibility:public"],
)

go_tool_binary(
    name = "compile",
    srcs = [
        "compile.go",
        "filter.go",
    ],
    visibility = ["//visibility:public"],
)

go_tool_binary(
    name = "filter_tags",
    srcs = [
        "filter.go",
        "filter_tags.go",
    ],
    visibility = ["//visibility:public"],
)
