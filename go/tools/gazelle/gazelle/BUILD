load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_binary", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "diff.go",
        "fix.go",
        "main.go",
        "print.go",
    ],
    deps = [
        "//go/tools/gazelle/config:go_default_library",
        "//go/tools/gazelle/merger:go_default_library",
        "//go/tools/gazelle/packages:go_default_library",
        "//go/tools/gazelle/rules:go_default_library",
        "//go/tools/gazelle/wspace:go_default_library",
        "@com_github_bazelbuild_buildtools//build:go_default_library",
        "@com_github_bazelbuild_buildtools//differ:go_default_library",
    ],
)

go_binary(
    name = "gazelle",
    library = ":go_default_library",
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = [
        "fix_test.go",
        "integration_test.go",
    ],
    library = ":go_default_library",
)
