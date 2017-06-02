load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "go_default_xtest",
    srcs = ["stamped_bin_test.go"],
    deps = ["//examples/stamped_bin/stamp:go_default_library"],
    linkstamp = "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp",
)
