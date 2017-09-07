workspace(name = "io_bazel_rules_go")

load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
load("@io_bazel_rules_go//proto:def.bzl", "proto_register_toolchains")
go_rules_dependencies()
go_register_toolchains()
proto_register_toolchains()

# Needed for tests
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "test_environment")
test_environment()
