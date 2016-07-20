workspace(name = "io_bazel_rules_go")

load("//go:def.bzl", "go_repositories")

go_repositories()

GLOG_BUILD = """
load("@//go:def.bzl", "go_prefix", "go_library")

go_prefix("github.com/golang/glog")

go_library(
    name = "go_default_library",
    srcs = [
        "glog.go",
        "glog_file.go",
    ],
    visibility = ["//visibility:public"],
)
"""

new_git_repository(
    name = "com_github_golang_glog",
    build_file_content = GLOG_BUILD,
    commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
    remote = "https://github.com/golang/glog.git",
)

git_repository(
    name = "io_bazel_buildifier",
    commit = "0ca1d7991357ae7a7555589af88930d82cf07c0a",
    remote = "https://github.com/bazelbuild/buildifier.git",
)

local_repository(
    name = "io_bazel_rules_go",
    path = ".",
)
