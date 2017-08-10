load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "labeler.go",
        "resolve.go",
        "resolve_external.go",
        "resolve_structured.go",
        "resolve_vendored.go",
    ],
    deps = [
        "@io_bazel_rules_go//go/tools/gazelle/config:go_default_library",
        "@org_golang_x_tools//go/vcs:go_default_library",
    ],
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    srcs = [
        "labeler_test.go",
        "resolve_external_test.go",
        "resolve_structured_test.go",
        "resolve_test.go",
    ],
    deps = [
        "@io_bazel_rules_go//go/tools/gazelle/config:go_default_library",
        "@org_golang_x_tools//go/vcs:go_default_library",
    ],
    library = ":go_default_library",
    size = "small",
)
