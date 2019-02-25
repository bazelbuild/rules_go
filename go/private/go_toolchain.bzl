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

load("@io_bazel_rules_go//go/platform:list.bzl", "GOOS_GOARCH")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoSDK")
load("@io_bazel_rules_go//go/private:actions/archive.bzl", "emit_archive")
load("@io_bazel_rules_go//go/private:actions/asm.bzl", "emit_asm")
load("@io_bazel_rules_go//go/private:actions/binary.bzl", "emit_binary")
load("@io_bazel_rules_go//go/private:actions/compile.bzl", "emit_compile")
load("@io_bazel_rules_go//go/private:actions/cover.bzl", "emit_cover")
load("@io_bazel_rules_go//go/private:actions/link.bzl", "emit_link")
load("@io_bazel_rules_go//go/private:actions/pack.bzl", "emit_pack")
load("@io_bazel_rules_go//go/private:actions/stdlib.bzl", "emit_stdlib")

def _go_toolchain_impl(ctx):
    sdk = ctx.attr.sdk[GoSDK]
    cross_compile = ctx.attr.goos != sdk.goos or ctx.attr.goarch != sdk.goarch
    return [platform_common.ToolchainInfo(
        # Public fields
        name = ctx.label.name,
        cross_compile = cross_compile,
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
            stdlib = emit_stdlib,
        ),
        flags = struct(
            compile = (),
            link = ctx.attr.link_flags,
            link_cgo = ctx.attr.cgo_link_flags,
        ),
        sdk = sdk,

        # Internal fields -- may be read by emit functions.
        _builder = ctx.executable.builder,
    )]

_go_toolchain = rule(
    _go_toolchain_impl,
    attrs = {
        # Minimum requirements to specify a toolchain
        "builder": attr.label(
            mandatory = True,
            cfg = "host",
            executable = True,
            doc = "Tool used to execute most Go actions",
        ),
        "goos": attr.string(
            mandatory = True,
            doc = "Default target OS",
        ),
        "goarch": attr.string(
            mandatory = True,
            doc = "Default target architecture",
        ),
        "sdk": attr.label(
            mandatory = True,
            providers = [GoSDK],
            doc = "The SDK this toolchain is based on",
        ),
        # Optional extras to a toolchain
        "link_flags": attr.string_list(
            doc = "Flags passed to the Go internal linker",
        ),
        "cgo_link_flags": attr.string_list(
            doc = "Flags passed to the external linker (if it is used)",
        ),
    },
    doc = "Defines a Go toolchain based on an SDK",
    provides = [platform_common.ToolchainInfo],
)

def go_toolchain(name, target, sdk, host = None, constraints = [], **kwargs):
    """See go/toolchains.rst#go-toolchain for full documentation."""

    if not host:
        host = target
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
        sdk = sdk,
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

def generate_toolchains(host, sdk, builder):
    host_goos, _, host_goarch = host.partition("_")
    toolchains = []
    for target_goos, target_goarch in GOOS_GOARCH:
        target = "{}_{}".format(target_goos, target_goarch)
        toolchain_name = "go_" + target
        link_flags = []
        cgo_link_flags = []
        if "darwin" in host:
            cgo_link_flags.extend(["-shared", "-Wl,-all_load"])
        if "linux" in host:
            cgo_link_flags.append("-Wl,-whole-archive")

        # Add the primary toolchain
        toolchains.append(dict(
            name = toolchain_name,
            host = host,
            target = target,
            sdk = sdk,
            builder = builder,
            link_flags = link_flags,
            cgo_link_flags = cgo_link_flags,
        ))
    return toolchains

def generate_toolchain_names():
    # Keep in sync with generate_toolchains
    return [
        "go_{}_{}".format(target_goos, target_goarch)
        for target_goos, target_goarch in GOOS_GOARCH
    ]
