load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "useful_proto",
    srcs = ["useful.proto"],
    rules_go_repo_only_for_internal_use = "@",
    visibility = ["//visibility:public"],
    deps = ["@com_github_golang_protobuf//ptypes/duration:go_default_library"],
)
