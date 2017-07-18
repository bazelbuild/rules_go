load("@io_bazel_rules_go//go/private:go_tool_binary.bzl", "go_tool_binary")
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "filter_test",
    srcs = [
        "filter.go",
        "filter_test.go",
    ],
    size = "small",
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
        "flags.go",
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

go_tool_binary(
    name = "generate_test_main",
    srcs = [
        "filter.go",
        "generate_test_main.go",
    ],
    visibility = ["//visibility:public"],
)

go_tool_binary(
    name = "link",
    srcs = [
        "flags.go",
        "link.go",
    ],
    visibility = ["//visibility:public"],
)

go_tool_binary(
    name = "cgo",
    srcs = [
        "flags.go",
        "filter.go",
        "cgo.go",
    ],
    visibility = ["//visibility:public"],
)

go_tool_binary(
    name = "md5sum",
    srcs = [
        "md5sum.go",
    ],
    visibility = ["//visibility:public"],
)

