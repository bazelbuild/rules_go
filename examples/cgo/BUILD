package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_library", "go_test", "cgo_library")

cgo_library(
    name = "cgo_lib",
    srcs = [
        "import_example.go",
        "export_example.go",
        "use_exported.h",
        "use_exported.c",
    ],
    deps = ["//examples/cgo/cc_dependency:version"],
    linkopts = ["-lm"],
    visibility = ["//visibility:private"],
)

go_library(
    name = "go_default_library",
    srcs = [
        "pure_go.go",
    ],
    library = ":cgo_lib",
)

go_test(
    name = "cgo_lib_test",
    srcs = ["cgo_lib_test.go"],
    library = ":cgo_lib",
)
