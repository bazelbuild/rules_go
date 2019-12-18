[alias(
    name = name,
    actual = "@bazel_tools//platforms:{}".format(name),
    visibility = ["//visibility:public"],
) for name in [
    # OS constraint_values
    "android",
    "freebsd",
    "ios",
    "linux",
    "osx",
    "windows",

    # Arch constraint_values
    "aarch64",
    "arm",
    "ppc",
    "s390x",
    "x86_32",
    "x86_64",

    # constraint_settings
    "os",
    "cpu",
]]
