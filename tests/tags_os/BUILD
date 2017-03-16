load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        # Filtered by filename suffix
        "foo_darwin.go",
        "foo_linux.go",
        # Filtered by tag
        "foo_unknown.go",
        "bar_d.go",
        "bar_l.go",
        "bar_unknown.go",
    ],
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["tags_os_test.go"],
    library = ":go_default_library",
)
