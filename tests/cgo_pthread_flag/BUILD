load("//go:def.bzl", "cgo_library", "go_library", "go_test")

cgo_library(
    name = "cgo_default_library",
    srcs = ["cgo_pthread_flag.go"],
)

go_library(
    name = "go_default_library",
    library = ":cgo_default_library",
)

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["cgo_pthread_flag_test.go"],
    library = ":go_default_library",
)
