load("//go/private:go_tool_binary.bzl", "go_tool_binary")
load("//go:def.bzl", "go_test")

go_tool_binary(
    name = "filter_tags",
    srcs = ["filter_tags.go"],
)

go_test(
    name = "filter_tags_tags",
    srcs = [
        "filter_tags.go",
        "filter_tags_test.go",
    ],
)
