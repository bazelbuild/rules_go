load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["merger.go"],
    visibility = ["//visibility:public"],
    deps = ["@com_github_bazelbuild_buildtools//build:go_default_library"],
)

go_test(
    name = "go_default_test",
    srcs = ["merger_test.go"],
    library = ":go_default_library",
    deps = ["@com_github_bazelbuild_buildtools//build:go_default_library"],
)
