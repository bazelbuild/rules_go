workspace(name = "io_bazel_rules_go")

load("//go:def.bzl", "go_repositories", "go_repository")

go_repositories()

# Needed for examples
go_repository(
    name = "com_github_golang_glog",
    commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
    importpath = "github.com/golang/glog",
)

# Protocol buffers

load("//proto:go_proto_library.bzl", "go_proto_repositories")

go_proto_repositories()
