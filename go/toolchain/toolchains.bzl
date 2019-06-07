# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
load(
    "@io_bazel_rules_go_compat//:darwin.bzl",
    "DEFAULT_DARWIN_CONSTRAINT_VALUE",
)

# These symbols should be loaded from sdk.bzl or deps.bzl instead of here..
DEFAULT_VERSION = _DEFAULT_VERSION
MIN_SUPPORTED_VERSION = _MIN_SUPPORTED_VERSION
SDK_REPOSITORIES = _SDK_REPOSITORIES
go_register_toolchains = _go_register_toolchains

def declare_constraints():
    """Generates constraint_values and platform targets for valid platforms.

    Each constraint_value corresponds to a valid goos or goarch.
    The goos and goarch values belong to the constraint_settings
    @bazel_tools//platforms:os and @bazel_tools//platforms:cpu, respectively.
    To avoid redundancy, if there is an equivalent value in @bazel_tools,
    we define an alias here instead of another constraint_value.

    There is a special constraint_setting for Darwin, "darwin_constraint".
    The value is "is_darwin" when the target is macOS or iOS and "not_darwin"
    otherwise.

    Each platform defined here selects a goos and goarch constraint value.
    These platforms may be used with --platforms for cross-compilation,
    though users may create their own platforms (and
    @bazel_tools//platforms:default_platform will be used most of the time).
    """
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

    native.constraint_setting(
        name = "darwin_constraint",
        default_constraint_value = DEFAULT_DARWIN_CONSTRAINT_VALUE,
    )

    native.constraint_value(
        name = "is_darwin",
        constraint_setting = ":darwin_constraint",
    )

    native.constraint_value(
        name = "not_darwin",
        constraint_setting = ":darwin_constraint",
    )

    native.constraint_setting(
        name = "cgo_constraint",
        default_constraint_value = ":cgo_on",
    )

    native.constraint_value(
        name = "cgo_on",
        constraint_setting = ":cgo_constraint",
    )

    native.constraint_value(
        name = "cgo_off",
        constraint_setting = ":cgo_constraint",
    )

    for p in PLATFORMS:
        for cgo in (True, False):
            cgo_constraint = ":cgo_on" if cgo else ":cgo_off"
            constraints = [
                p.os_constraint,
                p.arch_constraint,
                cgo_constraint,
            ]
            if p.goos == "darwin":
                constraints.append(":is_darwin")
            else:
                constraints.append(":not_darwin")

            cgo_suffix = "_cgo" if cgo else ""
            native.platform(
                name = p.name + cgo_suffix,
                constraint_values = constraints,
            )
