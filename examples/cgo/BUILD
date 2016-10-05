package(
    default_visibility = ["//visibility:public"],
)

load("//go:def.bzl", "go_library", "go_test", "cgo_library")

cgo_library(
    name = "cgo_lib",
    srcs = [
        "export_example.go",
        "generated.go",
        "import_example.go",
        "use_exported.c",
        "use_exported.h",
    ],
    cdeps = ["//examples/cgo/cc_dependency:version"],
    clinkopts = ["-lm"],
    copts = ["-DDEFINED_IN_COPTS=1"],
    visibility = ["//visibility:private"],
    deps = [":sub"],
)

go_library(
    name = "go_default_library",
    srcs = [
        "pure_go.go",
    ],
    library = ":cgo_lib",
)

cgo_library(
    name = "sub",
    srcs = ["sub/floor.go"],
    clinkopts = ["-lm"],
    visibility = ["//visibility:private"],
)

go_test(
    name = "cgo_lib_test",
    srcs = ["cgo_lib_test.go"],
    library = ":cgo_lib",
)

genrule(
    name = "generate_go_src",
    srcs = ["generated.go.tpl"],
    outs = ["generated.go"],
    cmd = "cp -f $< $@",
    visibility = ["//visibility:private"],
)
