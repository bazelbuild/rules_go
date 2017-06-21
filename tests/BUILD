load(":bazel_tests.bzl", "md5_sum")

md5_sum(
    name = "all_rules_md5",
    srcs = ["//go:all_rules"],
    visibility = ["//visibility:private"],
)

# Consuming the above md5_sum rule directly into the data deps of a sh_test results in the
# files just not appearing, and the dependancy not triggering.
# If we wrap it in a filegroup first however it just works.
filegroup(
    name = "rules_go_deps",
    srcs = [":all_rules_md5"],
    visibility = ["//visibility:public"],
)
