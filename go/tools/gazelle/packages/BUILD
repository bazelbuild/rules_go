load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "doc.go",
        "fileinfo.go",
        "package.go",
        "walk.go",
    ],
    deps = [
        "//go/tools/gazelle/config:go_default_library",
        "@com_github_bazelbuild_buildtools//build:go_default_library",
    ],
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    srcs = [
        "fileinfo_test.go",
        "package_test.go",
    ],
    library = ":go_default_library",
    size = "small",
)

go_test(
    name = "go_default_xtest",
    srcs = ["walk_test.go"],
    deps = [
        ":go_default_library",
        "//go/tools/gazelle/config:go_default_library",
        "@com_github_bazelbuild_buildtools//build:go_default_library",
    ],
    size = "small",
)
