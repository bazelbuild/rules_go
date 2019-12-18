[alias(
    name = name,
    actual = "@platforms//os:{}".format(name),
    visibility = ["//visibility:public"],
) for name in (
    "android",
    "freebsd",
    "ios",
    "linux",
    "os",
    "osx",
    "windows",
)]

[alias(
    name = name,
    actual = "@platforms//cpu:{}".format(name),
    visibility = ["//visibility:public"],
) for name in (
    "aarch64",
    "arm",
    "cpu",
    "ppc",
    "s390x",
    "x86_32",
    "x86_64",
)]
