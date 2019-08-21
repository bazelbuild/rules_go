# Copyright 2014 The Bazel Authors. All rights reserved.
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
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
)
load(
    "@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "go_archive_aspect",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoSDK",
)
load(
    "@io_bazel_rules_go//go/platform:list.bzl",
    "GOARCH",
    "GOOS",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODES",
    "LINKMODE_NORMAL",
    "LINKMODE_PLUGIN",
    "LINKMODE_SHARED",
)
load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

_SHARED_ATTRS = {
    "basename": attr.string(),
    "data": attr.label_list(allow_files = True),
    "srcs": attr.label_list(allow_files = go_exts + asm_exts + cgo_exts),
    "gc_goopts": attr.string_list(),
    "gc_linkopts": attr.string_list(),
    "x_defs": attr.string_dict(),
    "linkmode": attr.string(values = LINKMODES, default = LINKMODE_NORMAL),
    "out": attr.string(),
    "cgo": attr.bool(),
    "cdeps": attr.label_list(),
    "cppopts": attr.string_list(),
    "copts": attr.string_list(),
    "cxxopts": attr.string_list(),
    "clinkopts": attr.string_list(),
}

def _go_binary_impl(ctx):
    """go_binary_impl emits actions for compiling and linking a go executable."""
    go = go_context(ctx)

    is_main = go.mode.link not in (LINKMODE_SHARED, LINKMODE_PLUGIN)
    library = go.new_library(go, importable = False, is_main = is_main)
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    name = ctx.attr.basename
    if not name:
        name = ctx.label.name
    executable = None
    if ctx.attr.out:
        # Use declare_file instead of attr.output(). When users set output files
        # directly, Bazel warns them not to use the same name as the rule, which is
        # the common case with go_binary.
        executable = ctx.actions.declare_file(ctx.attr.out)
    archive, executable, runfiles = go.binary(
        go,
        name = name,
        source = source,
        gc_linkopts = gc_linkopts(ctx),
        version_file = ctx.version_file,
        info_file = ctx.info_file,
        executable = executable,
    )
    return [
        library,
        source,
        archive,
        OutputGroupInfo(
            cgo_exports = archive.cgo_exports,
            compilation_outputs = [archive.data.file],
        ),
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles,
            executable = executable,
        ),
    ]

go_binary = go_rule(
    _go_binary_impl,
    attrs = dict({
        "deps": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "embed": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "importpath": attr.string(),
        "pure": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "static": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "race": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "msan": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "goos": attr.string(
            values = GOOS.keys() + ["auto"],
            default = "auto",
        ),
        "goarch": attr.string(
            values = GOARCH.keys() + ["auto"],
            default = "auto",
        ),
    }.items() + _SHARED_ATTRS.items()),
    executable = True,
)
"""See go/core.rst#go_binary for full documentation."""

def _go_tool_binary_impl(ctx):
    sdk = ctx.attr.sdk[GoSDK]
    name = ctx.label.name
    if sdk.goos == "windows":
        name += ".exe"
    out = ctx.actions.declare_file(name)

    command_tpl = ("{go} tool compile -o {out}.a -I {goroot} -trimpath=$PWD $@ && " +
                   "{go} tool link -o {out} -L {goroot} {out}.a && " +
                   "rm {out}.a")
    command = command_tpl.format(
        go = shell.quote(sdk.go.path),
        goroot = shell.quote(sdk.root_file.dirname),
        out = shell.quote(out.path),
    )

    ctx.actions.run_shell(
        inputs = sdk.libs + sdk.headers + sdk.tools + ctx.files.srcs + [sdk.go],
        outputs = [out],
        env = {"GOROOT": sdk.root_file.dirname},  # NOTE(#2005): avoid realpath in sandbox
        command = command,
        arguments = [f.path for f in ctx.files.srcs],
        mnemonic = "GoToolchainBinary",
    )

    return [DefaultInfo(
        files = depset([out]),
        executable = out,
    )]

go_tool_binary = rule(
    implementation = _go_tool_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Source files for the binary. Must be in 'package main'.",
        ),
        "sdk": attr.label(
            mandatory = True,
            providers = [GoSDK],
            doc = "The SDK containing tools and libraries to build this binary",
        ),
    },
    executable = True,
    doc = """Used instead of go_binary for executables used in the toolchain.

go_tool_binary depends on tools and libraries that are part of the Go SDK.
It does not depend on other toolchains. It can only compile binaries that
just have a main package and only depend on the standard library and don't
require build constraints.
""",
)

def gc_linkopts(ctx):
    gc_linkopts = [
        ctx.expand_make_variables("gc_linkopts", f, {})
        for f in ctx.attr.gc_linkopts
    ]
    return gc_linkopts
