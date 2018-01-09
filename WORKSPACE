workspace(name = "io_bazel_rules_go")

load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
load("@io_bazel_rules_go//proto:def.bzl", "proto_register_toolchains")

go_rules_dependencies()

go_register_toolchains()

# Needed for tests
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "test_environment")

test_environment()

load("@io_bazel_rules_go//tests/legacy/test_chdir:remote.bzl", "test_chdir_remote")

test_chdir_remote()

load("@io_bazel_rules_go//tests/integration/popular_repos:popular_repos.bzl", "popular_repos")

popular_repos()
