load(":bazel_tests.bzl", "md5_sum")

md5_sum(
    name = "all_rules_md5",
    srcs = ["//go:all_rules"],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "rules_go_deps",
    srcs = [":all_rules_md5"],
    visibility = ["//visibility:public"],
)