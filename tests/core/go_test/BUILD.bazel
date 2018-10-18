load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

test_suite(
    name = "go_test",
)

go_library(
    name = "lib",
    srcs = ["lib.go"],
    cgo = True,
    importpath = "lib",
)

go_test(
    name = "internal_test",
    size = "small",
    srcs = ["internal_test.go"],
    embed = [":lib"],
    x_defs = {
        "Got": "Internal",
        "Expect": "Internal",
    },
)

go_test(
    name = "external_test",
    size = "small",
    srcs = ["external_test.go"],
    embed = [":lib"],
    x_defs = {
        "Got": "External",
        "Expect": "External",
    },
)

go_test(
    name = "combined_test",
    size = "small",
    srcs = [
        "external_test.go",
        "internal_test.go",
    ],
    embed = [":lib"],
    x_defs = {
        "Got": "Combined",
        "Expect": "Combined",
    },
)

go_test(
    name = "flag_test",
    size = "small",
    srcs = [
        "flag_test.go",
    ],
    args = [
        "-aflag",
        "somevalue",
    ],
)

go_test(
    name = "example_test",
    size = "small",
    srcs = ["example_test.go"],
    embed = [":lib"],
    x_defs = {
        "Got": "Example",
        "Expected": "Example",
    },
)

go_test(
    name = "only_testmain_test",
    size = "small",
    srcs = ["only_testmain_test.go"],
)

go_test(
    name = "external_importmap_test",
    size = "small",
    srcs = ["external_importmap_test.go"],
    embed = [":external_importmap_lib"],
    deps = [":external_importmap_dep"],
)

go_library(
    name = "external_importmap_lib",
    srcs = ["external_importmap_lib.go"],
    importmap = "x/github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap",
    importpath = "github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap",
)

go_library(
    name = "external_importmap_dep",
    srcs = ["external_importmap_dep.go"],
    importpath = "github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap_dep",
    deps = [":external_importmap_lib"],
)

go_test(
    name = "pwd_test",
    size = "small",
    srcs = ["pwd_test.go"],
)

go_test(
    name = "data_test",
    size = "small",
    embed = [":data_test_lib"],
)

go_library(
    name = "data_test_lib",
    srcs = [":data_test_srcs"],
    data = ["x"],
    importpath = "github.com/bazelbuild/rules_go/tests/core/go_test/data_test",
    deps = [":data_test_dep"],
)

filegroup(
    name = "data_test_srcs",
    srcs = ["data_test.go"],
)

go_library(
    name = "data_test_dep",
    srcs = ["data_test_dep.go"],
    data = ["y"],
    embed = [":data_test_embed"],
    importpath = "github.com/bazelbuild/rules_go/tests/core/go_test/data_test_dep",
)

go_library(
    name = "data_test_embed",
    srcs = ["data_test_embed.go"],
    data = ["z"],
    importpath = "github.com/bazelbuild/rules_go/tests/core/go_test/data_test_dep",
)
