load("//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "lib_proto",
    srcs = ["lib.proto"],
    visibility = ["//visibility:public"],
    deps = [
        "//examples/proto/dep:useful_proto",
        "@com_github_golang_protobuf//ptypes/wrappers:go_default_library",
    ],
)
