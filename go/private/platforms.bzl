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

# platforms.bzl defines PLATFORMS, a table that describes each possible
# target platform. This table is used to generate config_settings,
# constraint_values, platforms, and toolchains.

_goos_constraint_values = {
    "android": "@bazel_tools//platforms:android",
    "darwin": "@bazel_tools//platforms:osx",
    "freebsd": "@bazel_tools//platforms:freebsd",
    "linux": "@bazel_tools//platforms:linux",
    "windows": "@bazel_tools//platforms:windows",
}

_goarch_constraint_values = {
    "386": "@bazel_tools//platforms:x86_32",
    "amd64": "@bazel_tools//platforms:x86_64",
    "arm": "@bazel_tools//platforms:arm",
    "arm64": "@bazel_tools//platforms:aarch64",
    "ppc64le": "@bazel_tools//platforms:ppc",
    "s390x": "@bazel_tools//platforms:s390x",
}

GOOS_GOARCH = (
    ("android", "386"),
    ("android", "amd64"),
    ("android", "arm"),
    ("android", "arm64"),
    ("darwin", "386"),
    ("darwin", "amd64"),
    ("darwin", "arm"),
    ("darwin", "arm64"),
    ("dragonfly", "amd64"),
    ("freebsd", "386"),
    ("freebsd", "amd64"),
    ("freebsd", "arm"),
    ("linux", "386"),
    ("linux", "amd64"),
    ("linux", "arm"),
    ("linux", "arm64"),
    ("linux", "mips"),
    ("linux", "mips64"),
    ("linux", "mips64le"),
    ("linux", "mipsle"),
    ("linux", "ppc64"),
    ("linux", "ppc64le"),
    ("linux", "s390x"),
    ("nacl", "386"),
    ("nacl", "amd64p32"),
    ("nacl", "arm"),
    ("netbsd", "386"),
    ("netbsd", "amd64"),
    ("netbsd", "arm"),
    ("openbsd", "386"),
    ("openbsd", "amd64"),
    ("openbsd", "arm"),
    ("plan9", "386"),
    ("plan9", "amd64"),
    ("plan9", "arm"),
    ("solaris", "amd64"),
    ("windows", "386"),
    ("windows", "amd64"),
    ("js", "wasm"),
)

RACE_GOOS_GOARCH = (
    ("darwin", "amd64"),
    ("freebsd", "amd64"),
    ("linux", "amd64"),
    ("windows", "amd64"),
)

MSAN_GOOS_GOARCH = (
    ("linux", "amd64"),
)

def _generate_platforms():
    platforms = []
    for goos, goarch in GOOS_GOARCH:
        if goos in _goos_constraint_values:
            os_constraint = _goos_constraint_values[goos]
        else:
            os_constraint = "@io_bazel_rules_go//go/toolchain:" + goos
        if goarch in _goarch_constraint_values:
            arch_constraint = _goarch_constraint_values[goarch]
        else:
            arch_constraint = "@io_bazel_rules_go//go/toolchain:" + goarch
        platforms.append(struct(
            name = goos + "_" + goarch,
            goos = goos,
            goarch = goarch,
            os_constraint = os_constraint,
            arch_constraint = arch_constraint,
            has_default_constraints = True,
        ))
    for goarch in ("arm", "arm64", "386", "amd64"):
        platforms.append(struct(
            name = "ios_" + goarch,
            goos = "darwin",
            goarch = goarch,
            os_constraint = "@bazel_tools//platforms:ios",
            arch_constraint = _goarch_constraint_values[goarch],
            has_default_constraints = False,
        ))
    return platforms

PLATFORMS = _generate_platforms()

def generate_toolchain_names():
    return ["go_" + p.name for p in PLATFORMS]
