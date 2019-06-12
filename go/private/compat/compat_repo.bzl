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

def _go_rules_compat_impl(ctx):
    ctx.file("BUILD.bazel")
    ctx.symlink(ctx.attr.impl, "compat.bzl")

_go_rules_compat = repository_rule(
    implementation = _go_rules_compat_impl,
    attrs = {
        "impl": attr.label(),
    },
)

def go_rules_compat(**kwargs):
    impls = [23, 25]  # keep sorted
    if not native.bazel_version:
        # bazel_version is None in development builds, so we can't do a
        # version comparison. Use the newest version of the compat file.
        impl = impls[-1]
    else:
        bazel_version = versions.parse(native.bazel_version)
        impl = impls[0]
        for iv in impls[1:]:
            next_version = (0, iv, 0)
            if bazel_version < next_version:
                break
            impl = iv
    impl_label = "@io_bazel_rules_go//go/private:compat/v{}.bzl".format(impl)
    _go_rules_compat(impl = impl_label, **kwargs)
