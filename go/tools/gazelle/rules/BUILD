load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "construct.go",
        "doc.go",
        "generator.go",
        "resolve.go",
        "resolve_external.go",
        "resolve_structured.go",
        "resolve_vendored.go",
        "sort_labels.go",
    ],
    visibility = ["//visibility:public"],
    deps = [
        "//go/tools/gazelle/config:go_default_library",
        "//go/tools/gazelle/packages:go_default_library",
        "@com_github_bazelbuild_buildtools//build:go_default_library",
        "@org_golang_x_tools//go/vcs:go_default_library",
    ],
)

go_test(
    name = "go_default_test",
    srcs = [
        "resolve_external_test.go",
        "resolve_structured_test.go",
        "resolve_test.go",
    ],
    library = ":go_default_library",
    size = "small",
)

go_test(
    name = "go_default_xtest",
    srcs = ["generator_test.go"],
    deps = [
        ":go_default_library",
        "//go/tools/gazelle/config:go_default_library",
        "//go/tools/gazelle/packages:go_default_library",
        "//go/tools/gazelle/testdata:go_default_library",
        "@com_github_bazelbuild_buildtools//build:go_default_library",
    ],
    size = "small",
)
