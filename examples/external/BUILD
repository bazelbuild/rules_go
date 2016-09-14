load("//go:def.bzl", "go_binary", "xgo_binary")

go_binary(
    name = "record_log",
    srcs = [
        "main.go",
    ],
    deps = [
        "@com_github_golang_glog//:go_default_library",
    ],
)

xgo_binary(
    name = "linux_arm_record_log",
    os_arch = "linux_arm",
    deps = [
        ":record_log",
    ],
)
