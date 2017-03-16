load("//go/private:go_tool_binary.bzl", "go_tool_binary")
load("//go:def.bzl", "go_test")

go_tool_binary(
    name = "extract_package",
    srcs = ["extract.go"],
)

go_test(
    name = "extract_package_test",
    srcs = [
        "extract.go",
        "extract_test.go",
    ],
)
