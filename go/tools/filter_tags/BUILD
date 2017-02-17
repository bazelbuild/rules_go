package(default_visibility = ["//visibility:public"])

load("//go:def.bzl", "go_tool_library", "go_tool_binary", "go_tool_test")

go_tool_library(
    name = "filter_tags_lib",
    srcs = ["filter_tags.go"],
)

go_tool_binary(
    name = "filter_tags",
    library = ":filter_tags_lib",
)

go_tool_test(
    name = "filter_tags_test",
    srcs = ["filter_tags_test.go"],
    library = ":filter_tags_lib",
)
