workspace(name = "io_bazel_rules_go")

load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependancies", "go_register_toolchains", "go_repository")
go_rules_dependancies()
go_register_toolchains()

# Needed for examples
go_repository(
    name = "com_github_golang_glog",
    commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
    importpath = "github.com/golang/glog",
)

# Protocol buffers

load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_repositories")

go_proto_repositories()

# Needed for tests

load("@io_bazel_rules_go//tests:bazel_tests.bzl", "test_environment")
test_environment()

load("@io_bazel_rules_go//examples/bindata:bindata.bzl", "bindata_repositories")
bindata_repositories()
