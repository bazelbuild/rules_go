load("//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "lib_proto",
    srcs = ["lib.proto"],
    visibility = ["//visibility:public"],
    deps = [
        "//examples/proto/dep:useful_proto",
    ],
)
