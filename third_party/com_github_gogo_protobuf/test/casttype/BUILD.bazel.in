load("@io_bazel_rules_go//go:def.bzl", "go_library")

filegroup(
    name = "go_default_library_protos",
    srcs = ["casttype.proto"],
    visibility = ["//visibility:public"],
)

go_library(
    name = "go_default_library",
    srcs = ["mytypes.go"],
    importpath = "github.com/gogo/protobuf/test/casttype",
    visibility = ["//visibility:public"],
)
