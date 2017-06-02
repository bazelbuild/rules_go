load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "lib_proto",
    srcs = [
        "lib.proto",
        "lib2.proto",
    ],
    rules_go_repo_only_for_internal_use = "@",
    visibility = ["//visibility:public"],
    deps = ["//examples/proto/dep:useful_proto"],
)
