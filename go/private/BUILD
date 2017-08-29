load("@io_bazel_rules_go//go/private:go_toolchain.bzl", "go_toolchain_flags")

filegroup(
    name = "all_rules",
    srcs = glob(["**/*.bzl"]),
    visibility = ["//visibility:public"],
)

config_setting(
    name = "fastbuild",
    values = {"compilation_mode": "fastbuild"},
)

config_setting(
    name = "debug",
    values = {"compilation_mode": "dbg"},
)

config_setting(
    name = "optimized",
    values = {"compilation_mode": "opt"},
)

go_toolchain_flags(
    name = "go_toolchain_flags",
    compile_flags = select({
        "@io_bazel_rules_go//go/private:fastbuild": [],
        "@io_bazel_rules_go//go/private:debug": [
            "-N",
            "-l",
        ],
        "@io_bazel_rules_go//go/private:optimized": [],
    }),
    visibility = ["@io_bazel_rules_go//go/toolchain:__subpackages__"],
)
