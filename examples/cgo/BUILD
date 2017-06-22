package(
    default_visibility = ["//visibility:public"],
)

load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "export_example.go",
        "generated.go",
        "import_example.go",
        "use_exported.c",
        "use_exported.h",
        "pure_go.go",
    ],
    cgo = True,
    cdeps = ["//examples/cgo/cc_dependency:version"],
    clinkopts = ["-lm"],
    copts = ["-DDEFINED_IN_COPTS=1"],
    visibility = ["//visibility:public"],
    deps = [":sub"],
)

go_library(
    name = "sub",
    srcs = ["sub/floor.go"],
    cgo = True,
    clinkopts = ["-lm"],
    visibility = ["//visibility:private"],
)

go_test(
    name = "cgo_lib_test",
    srcs = ["cgo_lib_test.go"],
    library = ":go_default_library",
    size = "small",
)

genrule(
    name = "generate_go_src",
    srcs = ["generated.go.tpl"],
    outs = ["generated.go"],
    cmd = "cp -f $< $@",
    visibility = ["//visibility:private"],
)
