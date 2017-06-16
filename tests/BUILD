load(":bazel_tests.bzl", "md5_sum")

md5_sum(
  name = "all_rules",
  srcs = ["//go:all_rules"],
  visibility = ["//visibility:private"],
)

filegroup(
  name = "rules_go_deps",
  srcs = [":all_rules"],
  visibility = ["//visibility:public"],
)