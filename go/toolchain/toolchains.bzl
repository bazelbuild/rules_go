load(
    "@io_bazel_rules_go//go/private:sdk.bzl",
    _go_register_toolchains = "go_register_toolchains",
)
load(
    "@io_bazel_rules_go//go/private:sdk_list.bzl",
    _DEFAULT_VERSION = "DEFAULT_VERSION",
    _MIN_SUPPORTED_VERSION = "MIN_SUPPORTED_VERSION",
    _SDK_REPOSITORIES = "SDK_REPOSITORIES",
)
load(
    "@io_bazel_rules_go//go/private:platforms.bzl",
    "PLATFORMS",
)

# These symbols should be loaded from sdk.bzl or deps.bzl instead of here..
DEFAULT_VERSION = _DEFAULT_VERSION
MIN_SUPPORTED_VERSION = _MIN_SUPPORTED_VERSION
SDK_REPOSITORIES = _SDK_REPOSITORIES
go_register_toolchains = _go_register_toolchains

def declare_constraints():
    goos_constraints = {p.goos: p.os_constraint for p in PLATFORMS if p.has_default_constraints}
    for goos, constraint in goos_constraints.items():
        if constraint.startswith("@io_bazel_rules_go//go/toolchain:"):
            native.constraint_value(
                name = goos,
                constraint_setting = "@bazel_tools//platforms:os",
            )
        else:
            native.alias(
                name = goos,
                actual = constraint,
            )

    goarch_constraints = {p.goarch: p.arch_constraint for p in PLATFORMS if p.has_default_constraints}
    for goarch, constraint in goarch_constraints.items():
        if constraint.startswith("@io_bazel_rules_go//go/toolchain:"):
            native.constraint_value(
                name = goarch,
                constraint_setting = "@bazel_tools//platforms:cpu",
            )
        else:
            native.alias(
                name = goarch,
                actual = constraint,
            )

    for p in PLATFORMS:
        native.platform(
            name = p.name,
            constraint_values = [
                p.os_constraint,
                p.arch_constraint,
            ],
        )
