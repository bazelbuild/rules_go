load(
    "//go/private:sdk.bzl",
    _go_register_toolchains = "go_register_toolchains",
)
load(
    "//go/private:sdk_list.bzl",
    _DEFAULT_VERSION = "DEFAULT_VERSION",
    _MIN_SUPPORTED_VERSION = "MIN_SUPPORTED_VERSION",
    _SDK_REPOSITORIES = "SDK_REPOSITORIES",
)
load(
    "//go/platform:list.bzl",
    "GOARCH",
    "GOOS",
    "GOOS_GOARCH",
)

# These symbols should be loaded from sdk.bzl or deps.bzl instead of here..
DEFAULT_VERSION = _DEFAULT_VERSION
MIN_SUPPORTED_VERSION = _MIN_SUPPORTED_VERSION
SDK_REPOSITORIES = _SDK_REPOSITORIES
go_register_toolchains = _go_register_toolchains

def declare_constraints():
    for goos, constraint in GOOS.items():
        if constraint:
            native.alias(
                name = goos,
                actual = constraint,
            )
        else:
            native.constraint_value(
                name = goos,
                constraint_setting = "@bazel_tools//platforms:os",
            )
    for goarch, constraint in GOARCH.items():
        if constraint:
            native.alias(
                name = goarch,
                actual = constraint,
            )
        else:
            native.constraint_value(
                name = goarch,
                constraint_setting = "@bazel_tools//platforms:cpu",
            )
    for goos, goarch in GOOS_GOARCH:
        native.platform(
            name = goos + "_" + goarch,
            constraint_values = [
                ":" + goos,
                ":" + goarch,
            ],
        )
