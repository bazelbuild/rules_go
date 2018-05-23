# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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
"""
Toolchain rules used by go.
"""

load("@io_bazel_rules_go//go/private:actions/archive.bzl", "emit_archive")
load("@io_bazel_rules_go//go/private:actions/asm.bzl", "emit_asm")
load("@io_bazel_rules_go//go/private:actions/binary.bzl", "emit_binary")
load("@io_bazel_rules_go//go/private:actions/compile.bzl", "emit_compile")
load("@io_bazel_rules_go//go/private:actions/cover.bzl", "emit_cover")
load("@io_bazel_rules_go//go/private:actions/link.bzl", "emit_link")
load("@io_bazel_rules_go//go/private:actions/pack.bzl", "emit_pack")

def _go_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        name = ctx.label.name,
        cross_compile = ctx.attr.cross_compile,
        default_goos = ctx.attr.goos,
        default_goarch = ctx.attr.goarch,
        actions = struct(
            archive = emit_archive,
            asm = emit_asm,
            binary = emit_binary,
            compile = emit_compile,
            cover = emit_cover,
            link = emit_link,
            pack = emit_pack,
        ),
        flags = struct(
            compile = (),
            link = ctx.attr.link_flags,
            link_cgo = ctx.attr.cgo_link_flags,
        ),
    )]

_go_toolchain = rule(
    _go_toolchain_impl,
    attrs = {
        # Minimum requirements to specify a toolchain
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "cross_compile": attr.bool(default = False),
        # Optional extras to a toolchain
        "link_flags": attr.string_list(default = []),
        "cgo_link_flags": attr.string_list(default = []),
    },
)

def go_toolchain(name, target, host = None, constraints = [], **kwargs):
    """See go/toolchains.rst#go-toolchain for full documentation."""

    if not host:
        host = target
    cross = host != target
    goos, _, goarch = target.partition("_")
    target_constraints = constraints + [
        "@io_bazel_rules_go//go/toolchain:" + goos,
        "@io_bazel_rules_go//go/toolchain:" + goarch,
    ]
    host_goos, _, host_goarch = host.partition("_")
    exec_constraints = [
        "@io_bazel_rules_go//go/toolchain:" + host_goos,
        "@io_bazel_rules_go//go/toolchain:" + host_goarch,
    ]

    impl_name = name + "-impl"
    _go_toolchain(
        name = impl_name,
        goos = goos,
        goarch = goarch,
        cross_compile = cross,
        tags = ["manual"],
        visibility = ["//visibility:public"],
        **kwargs
    )
    native.toolchain(
        name = name,
        toolchain_type = "@io_bazel_rules_go//go:toolchain",
        exec_compatible_with = exec_constraints,
        target_compatible_with = target_constraints,
        toolchain = ":" + impl_name,
    )
