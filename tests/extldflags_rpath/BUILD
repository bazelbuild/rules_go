load("//go:def.bzl", "go_binary")

go_binary(
    name = "extldflags_rpath",
    srcs = ["main.go"],
    gc_linkopts = [
        "-linkmode",
        "external",
        "-extldflags",
        "-Wl,-rpath -Wl,/foo",
        "-extldflags",
        "-Wl,-rpath -Wl,/bar",
    ],
)

sh_test(
    name = "extldflags_rpath_test",
    srcs = ["extldflags_rpath_test.sh"],
    args = ["$(location :extldflags_rpath)"],
    data = [":extldflags_rpath"],
)
