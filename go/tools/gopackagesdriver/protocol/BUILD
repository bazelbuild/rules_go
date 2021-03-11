load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "protocol",
    srcs = [
        "driver.go",
        "protocol.go",
    ],
    importpath = "github.com/bazelbuild/rules_go/go/tools/gopackagesdriver/protocol",
    visibility = ["//go/tools/gopackagesdriver:__subpackages__"],
    deps = [
        "@org_golang_x_tools//go/packages",
    ],
)
