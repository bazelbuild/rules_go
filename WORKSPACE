workspace(name = "io_bazel_rules_go")

load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
go_register_toolchains()
register_toolchains(
  "@io_bazel_rules_go//proto:proto",
  "@io_bazel_rules_go//proto:go_proto",
  "@io_bazel_rules_go//proto:go_grpc",
)

# Needed for tests
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "test_environment")
test_environment()
