load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["generator.go"],
    visibility = ["//visibility:public"],
    deps = [
        "//go/tools/gazelle/packages:go_default_library",
        "//go/tools/gazelle/rules:go_default_library",
        "@com_github_bazelbuild_buildifier//build:go_default_library",
    ],
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["generator_test.go"],
    library = ":go_default_library",
    deps = [
        "//go/tools/gazelle/rules:go_default_library",
        "//go/tools/gazelle/testdata:go_default_library",
    ],
)
