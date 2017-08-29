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
        "pure_go.go",
        "use_exported.c",
        "use_exported.h",
    ],
    cdeps = ["//examples/cgo/cc_dependency:version"],
    cgo = True,
    clinkopts = ["-lm"],
    copts = ["-DDEFINED_IN_COPTS=1"],
    visibility = ["//visibility:public"],
    deps = [":sub"],
)

# TODO(#746) exclude because gazelle does not recognise the rule below
# gazelle:exclude sub

go_library(
    name = "sub",
    srcs = ["sub/floor.go"],
    cgo = True,
    clinkopts = ["-lm"],
    visibility = ["//visibility:private"],
)

go_test(
    name = "cgo_lib_test",
    size = "small",
    srcs = ["cgo_lib_test.go"],
    library = ":go_default_library",
)

genrule(
    name = "generate_go_src",
    srcs = ["generated.go.tpl"],
    outs = ["generated.go"],
    cmd = "cp -f $< $@",
    visibility = ["//visibility:private"],
)
