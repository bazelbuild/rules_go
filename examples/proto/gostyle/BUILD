load("//proto:go_proto_library.bzl", "go_proto_library")

genrule(
    name = "copy",
    srcs = ["gostyle.proto"],
    outs = ["gostyle.gen.proto"],
    cmd = "sed -e 's/ano.proto/any.proto/' $< > $@",
)

go_proto_library(
    name = "go_default_library",
    srcs = ["gostyle.gen.proto"],
    rules_go_repo_only_for_internal_use = "@",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_golang_protobuf//ptypes/any:go_default_library",
    ],
)
