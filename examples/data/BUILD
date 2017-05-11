load("//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["data.go"],
    data = ["data.txt"],
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    srcs = ["data_test.go"],
    # Uncomment this line and the demo test will pass.
    #data = ["data.txt"],
    library = ":go_default_library",
)
