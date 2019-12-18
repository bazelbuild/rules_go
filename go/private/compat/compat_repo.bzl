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

# This file provides an abstraction over parts of the Bazel API. It is
# intended to be stable across Bazel's breaking API changes so that rules_go
# can support a wider range of Bazel versions.
#
# The compatibility layer is implemented with a repository rule used to provide
# @io_bazel_rules_go_compat, which is declared by go_rules_dependencies.
# The repository has one file, compat.bzl, which is a symbolic link
# to a file in this directory. The destination of the symbolic link is
# determined by the current Bazel version. Each version of compat.bzl contains
# the same definitions but with different implementations. The version names
# like v18.bzl indicate the minimum version of Bazel for that file.

load("@io_bazel_rules_go//go/private:skylib/lib/versions.bzl", "versions")

def _choose(version_impls):
    """Picks the newest implementation supported by the current version of
    Bazel from a sequence of version / implementation pairs.

    Args:
        version_impls: sequence of pairs. The first element of each pair is a
            parsed semantic version tuple (for example, (1, 2, 3)). The
            second element is a value that may be returned. The sequence must be
            sorted by version.

    Returns: the value from the sequence corresponding to the maximum version
        that is less than the Bazel version. If the Bazel version is not set
        (in a development build), the last value is returned. If no Bazel
        version is supported, the first value is returned, and we hope for
        the best.
    """
    if not native.bazel_version:
        # bazel_version is None in development builds, so we can't do a
        # version comparison. Use the newest version of the compat file.
        return version_impls[-1][1]
    bazel_version = versions.parse(native.bazel_version)
    newest_supported_impl = version_impls[0][1]
    for v, impl in version_impls[1:]:
        if bazel_version < v:
            break
        newest_supported_impl = impl
    return newest_supported_impl

def _go_rules_compat_impl(ctx):
    ctx.file("BUILD.bazel")
    ctx.template("compat.bzl", ctx.attr.impl)
    ctx.template("platforms/BUILD.bazel", ctx.attr.platforms_build_file)

_go_rules_compat = repository_rule(
    implementation = _go_rules_compat_impl,
    attrs = {
        "impl": attr.label(),
        "platforms_build_file": attr.label(),
    },
)

def go_rules_compat(**kwargs):
    bzl_impl_labels = (
        ((0, 23, 0), "@io_bazel_rules_go//go/private:compat/v0_23.bzl"),
        ((0, 25, 0), "@io_bazel_rules_go//go/private:compat/v0_25.bzl"),
        ((1, 0, 0), "@io_bazel_rules_go//go/private:compat/v1_0.bzl"),
    )
    platforms_build_labels = (
        ((0, 23, 0), "@io_bazel_rules_go//go/private:compat/BUILD.platforms.v0_23.bzl"),
        ((0, 28, 0), "@io_bazel_rules_go//go/private:compat/BUILD.platforms.v0_28.bzl"),
    )
    _go_rules_compat(
        impl = _choose(bzl_impl_labels),
        platforms_build_file = _choose(platforms_build_labels),
        **kwargs
    )
