load("@io_bazel_rules_go//go:def.bzl", "cgo_library", "go_test")

cgo_library(
    name = "cgo_default_library",
    srcs = select({
        "@io_bazel_rules_go//go/platform:darwin_amd64": [
            "cgo_darwin.go",
        ],
        "@io_bazel_rules_go//go/platform:linux_amd64": [
            "cgo_linux.go",
        ],
        "@io_bazel_rules_go//go/platform:windows_amd64": [
            "cgo_windows.go",
        ],
    }),
    cdeps = select({
        "@io_bazel_rules_go//go/platform:darwin_amd64": [
            ":darwin_lib",
        ],
        "@io_bazel_rules_go//go/platform:linux_amd64": [
            ":linux_lib",
        ],
        "@io_bazel_rules_go//go/platform:windows_amd64": [
            ":windows_lib",
        ],
    }),
)

cc_library(
    name = "darwin_lib",
    srcs = ["darwin.c"],
)

cc_library(
    name = "linux_lib",
    srcs = ["linux.c"],
)

cc_library(
    name = "windows_lib",
    srcs = ["windows.c"],
)

go_test(
    name = "go_default_test",
    srcs = ["cgo_select_test.go"],
    library = ":cgo_default_library",
    size = "small",
)
