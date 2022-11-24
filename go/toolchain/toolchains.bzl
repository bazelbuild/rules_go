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
    "//go/private:platforms.bzl",
    "GOARCH_CONSTRAINTS",
    "GOOS_CONSTRAINTS",
    "PLATFORMS",
)

def declare_constraints():
    """Generates constraint_values and platform targets for valid platforms.

    Each constraint_value corresponds to a valid goos or goarch.
    The goos and goarch values belong to the constraint_settings
    @platforms//os:os and @platforms//cpu:cpu, respectively.
    To avoid redundancy, if there is an equivalent value in @platforms,
    we define an alias here instead of another constraint_value.

    Each platform defined here selects a goos and goarch constraint value.
    These platforms may be used with --platforms for cross-compilation,
    though users may create their own platforms (and
    @bazel_tools//platforms:default_platform will be used most of the time).
    """
    for goos, constraint in GOOS_CONSTRAINTS.items():
        if constraint.startswith("@io_bazel_rules_go//go/toolchain:"):
            native.constraint_value(
                name = goos,
                constraint_setting = "@platforms//os:os",
            )
        else:
            native.alias(
                name = goos,
                actual = constraint,
            )

    for goarch, constraint in GOARCH_CONSTRAINTS.items():
        if constraint.startswith("@io_bazel_rules_go//go/toolchain:"):
            native.constraint_value(
                name = goarch,
                constraint_setting = "@platforms//cpu:cpu",
            )
        else:
            native.alias(
                name = goarch,
                actual = constraint,
            )

    native.constraint_setting(
        name = "cgo_constraint",
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
        native.platform(
            name = p.name,
            constraint_values = p.constraints,
        )
