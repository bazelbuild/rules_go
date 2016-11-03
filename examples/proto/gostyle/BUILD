load("//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "go_default_library",
    srcs = ["gostyle.proto"],
    rules_go_repo_only_for_internal_use = "@",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_golang_protobuf//ptypes/any:go_default_library",
    ],
)
