config_setting(
    name = "darwin",
    values = {"cpu": "darwin"},
)

cc_library(
    name = "version",
    srcs = ["cxx_version.cc"],
    hdrs = ["version.h"],
    linkopts = ["-ldl"],
    visibility = ["//examples/cgo:__pkg__"],
    # TODO(yugui) Support darwin too and remove this workaround.
    # See also comments in cxx_version.cc.
    deps = select({
        ":darwin": [],
        "//conditions:default": [":c_version_wrap"],
    }),
)

cc_library(
    name = "c_version_orig",
    srcs = ["c_version.c"],
    hdrs = ["c_version.h"],
)

# Goes through genrule() to emulate prebuilt .so in srcs of cc_library.
genrule(
    name = "copy_c_version",
    srcs = [":c_version_orig"],
    outs = ["libc_version.so"],
    cmd = "cp \"$$(find $(SRCS) -name '*.so')\" $@",
    output_to_bindir = 1,
)

cc_library(
    name = "c_version_wrap",
    srcs = ["libc_version.so"],
    hdrs = ["c_version.h"],
)
