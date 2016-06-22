package(
    default_testonly = 1,
    default_visibility = ["//go/tools/gazelle:__subpackages__"],
)

load("//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["testdata.go"],
    data = glob(["repo/**/*.go"]),
)
