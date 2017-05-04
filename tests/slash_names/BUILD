load("//go:def.bzl", "go_library", "go_test")

go_library(
    name="a/pkg",
    srcs = ["a/pkg/pkg.go"],
)

go_library(
    name="b/pkg",
    srcs = ["b/pkg/pkg.go"],
)

go_test(
    name = "go_default_test",
    srcs = ["slash_test.go"],
    deps = [":a/pkg", ":b/pkg"],
)
