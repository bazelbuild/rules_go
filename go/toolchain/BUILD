package(default_visibility = ["//visibility:public"])

load(':toolchains.bzl', 'declare_toolchains')

constraint_value(name = "android", constraint_setting = "@bazel_tools//platforms:os")
constraint_value(name = "dragonfly", constraint_setting = "@bazel_tools//platforms:os")
constraint_value(name = "netbsd", constraint_setting = "@bazel_tools//platforms:os")
constraint_value(name = "openbsd", constraint_setting = "@bazel_tools//platforms:os")
constraint_value(name = "plan9", constraint_setting = "@bazel_tools//platforms:os")
constraint_value(name = "solaris", constraint_setting = "@bazel_tools//platforms:os")

constraint_value(name = "arm64", constraint_setting = "@bazel_tools//platforms:cpu")
constraint_value(name = "ppc64le", constraint_setting = "@bazel_tools//platforms:cpu")
constraint_value(name = "mips", constraint_setting = "@bazel_tools//platforms:cpu")
constraint_value(name = "mipsle", constraint_setting = "@bazel_tools//platforms:cpu")
constraint_value(name = "mips64", constraint_setting = "@bazel_tools//platforms:cpu")
constraint_value(name = "mips64le", constraint_setting = "@bazel_tools//platforms:cpu")

# Version constraints
constraint_setting(name = "go_version")
constraint_setting(name = "go_minor_version")
constraint_setting(name = "go_point_version")

constraint_value(name = "go1", constraint_setting = ":go_version")
constraint_value(name = "go1.8", constraint_setting = ":go_minor_version")
constraint_value(name = "go1.8.3", constraint_setting = ":go_point_version")
constraint_value(name = "go1.8.2", constraint_setting = ":go_point_version")
constraint_value(name = "go1.8.1", constraint_setting = ":go_point_version")
constraint_value(name = "go1.8.0", constraint_setting = ":go_point_version")
constraint_value(name = "go1.7", constraint_setting = ":go_minor_version")
constraint_value(name = "go1.7.6", constraint_setting = ":go_point_version")
constraint_value(name = "go1.7.5", constraint_setting = ":go_version")

declare_toolchains()
