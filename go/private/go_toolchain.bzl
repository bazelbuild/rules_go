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

load("@io_bazel_rules_go//go/private:platforms.bzl", "PLATFORMS")
load("@io_bazel_rules_go//go/private:providers.bzl", "CgoContextData", "GoSDK")
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
        _cgo_context_data = ctx.attr.cgo_context_data[CgoContextData] if ctx.attr.cgo_context_data else None,
    )]

go_toolchain = rule(
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
        "cgo_context_data": attr.label(
            providers = [CgoContextData],
            doc = "A target that collects information about the C/C++ toolchain.",
        ),
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

def declare_toolchains(host, sdk, builder):
    # keep in sync with generate_toolchain_names
    host_goos, _, host_goarch = host.partition("_")
    for p in PLATFORMS:
        link_flags = []
        cgo_link_flags = []
        if host_goos == "darwin":
            cgo_link_flags.extend(["-shared", "-Wl,-all_load"])
        if host_goos == "linux":
            cgo_link_flags.append("-Wl,-whole-archive")

        toolchain_name = "go_" + p.name
        impl_name = toolchain_name + "-impl"

        cgo_context_data = "@io_bazel_rules_go//:cgo_context_data" if p.cgo else None

        constraints = p.constraints
        if p.goos != host_goos or p.goarch != host_goarch:
            # When cross-compiling, don't require cgo_off.
            # It won't be set on a custom platform outside of //go/toolchain.
            constraints = [c for c in constraints if c != "@io_bazel_rules_go//go/toolchain:cgo_off"]
        else:
            # When compiling for the host platform, don't require cgo_on.
            # It won't be set on @bazel_tools//platforms:target_platform,
            # which is probably the target.
            constraints = [c for c in constraints if c != "@io_bazel_rules_go//go/toolchain:cgo_on"]

        go_toolchain(
            name = impl_name,
            goos = p.goos,
            goarch = p.goarch,
            sdk = sdk,
            builder = builder,
            link_flags = link_flags,
            cgo_link_flags = cgo_link_flags,
            cgo_context_data = cgo_context_data,
            tags = ["manual"],
            visibility = ["//visibility:public"],
        )
        native.toolchain(
            name = toolchain_name,
            toolchain_type = "@io_bazel_rules_go//go:toolchain",
            exec_compatible_with = [
                "@io_bazel_rules_go//go/toolchain:" + host_goos,
                "@io_bazel_rules_go//go/toolchain:" + host_goarch,
            ],
            target_compatible_with = constraints,
            toolchain = ":" + impl_name,
        )
