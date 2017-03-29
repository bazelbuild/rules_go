load("//go:def.bzl", "go_library", "go_test")

go_test(
    name = "go_default_test",
    srcs = [
        # Filtered by filename suffix
        "foo_linux_test.go",
        # Filtered by tag
        "foo_unknown_test.go",
        "bar_unknown_test.go",
    ],
    library = ":go_default_library",
)

# Contains more test cases. Checks that build constraints are applied to
# sources found through the library attribute.
go_library(
    name = "go_default_library",
    srcs = [
        "baz_linux_test.go",
        "baz_unknown_test.go",
    ],
)
