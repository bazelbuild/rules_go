load("//go:def.bzl", "cgo_library", "go_library", "go_test")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["build_constraints_test.go"],
    library = ":go_default_library",
)

go_library(
    name = "go_default_library",
    srcs = [
        # Check suffixes are filtered.
        "suffix_linux.go",
        "suffix_unknown.go",
        # Check that tags are observed.
        "tag_l.go",
        "tag_unknown.go",
        # Check that constraints apply to assembly files.
        "asm_linux.s",
        "asm_unknown.s",
    ],
    library = ":cgo_default_library",
)

cgo_library(
    name = "cgo_default_library",
    srcs = [
        # Check that constraints apply to cgo files.
        "cgo_linux.go",
        "cgo_unknown.go",
    ],
)
