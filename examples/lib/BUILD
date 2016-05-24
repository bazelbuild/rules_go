package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "add.s",
        "asm.go",
        "lib.go",
        "sub.s",
    ],
)

go_test(
    name = "lib_test",
    srcs = [
        "lib_test.go",
    ],
    library = ":go_default_library",
)

go_test(
    name = "lib_external_test",
    srcs = [
        "lib_x_test.go",
    ],
    deps = [
         ":go_default_library",
    ],
)
