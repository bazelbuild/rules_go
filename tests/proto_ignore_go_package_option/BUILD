load("//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
    name = "a_proto",
    srcs = ["a.proto"],
    deps = [
        "@com_github_golang_protobuf//ptypes/struct:go_default_library",
    ],
    ignore_go_package_option = 1,
)

go_proto_library(
    name = "b_proto",
    srcs = ["b.proto"],
    deps = [
        ":a_proto",
        "@com_github_golang_protobuf//ptypes/any:go_default_library",
    ],
    ignore_go_package_option = 1,
)
