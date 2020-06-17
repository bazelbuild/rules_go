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
    ":context.bzl",
    "go_context",
)
load(
    ":common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
)
load(
    ":providers.bzl",
    "GoLibrary",
    "GoSDK",
)
load(
    ":rules/transition.bzl",
    "go_transition_rule",
)
load(
    ":mode.bzl",
    "LINKMODE_PLUGIN",
    "LINKMODE_SHARED",
)

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

_go_binary_kwargs = {
    "implementation": _go_binary_impl,
    "attrs": {
        "srcs": attr.label_list(allow_files = go_exts + asm_exts + cgo_exts),
        "data": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            providers = [GoLibrary],
        ),
        "embed": attr.label_list(
            providers = [GoLibrary],
        ),
        "importpath": attr.string(),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "basename": attr.string(),
        "out": attr.string(),
        "cgo": attr.bool(),
        "cdeps": attr.label_list(),
        "cppopts": attr.string_list(),
        "copts": attr.string_list(),
        "cxxopts": attr.string_list(),
        "clinkopts": attr.string_list(),
        "_go_context_data": attr.label(default = "//:go_context_data"),
    },
    "executable": True,
    "toolchains": ["@io_bazel_rules_go//go:toolchain"],
}

go_binary = rule(**_go_binary_kwargs)
go_transition_binary = go_transition_rule(**_go_binary_kwargs)

def _go_tool_binary_impl(ctx):
    sdk = ctx.attr.sdk[GoSDK]
    name = ctx.label.name
    if sdk.goos == "windows":
        name += ".exe"

    cout = ctx.actions.declare_file(name + ".a")
    if sdk.goos == "windows":
        cmd = "@echo off\n {go} tool compile -o {cout} -trimpath=%cd% {srcs}".format(
            go = sdk.go.path.replace("/", "\\"),
            cout = cout.path,
            srcs = " ".join([f.path for f in ctx.files.srcs]),
        )
        bat = ctx.actions.declare_file(name + ".bat")
        ctx.actions.write(
            output = bat,
            content = cmd,
        )
        ctx.actions.run(
            executable = "cmd.exe",
            arguments = ["/S", "/C", bat.path.replace("/", "\\")],
            inputs = sdk.libs + sdk.headers + sdk.tools + ctx.files.srcs + [sdk.go, bat],
            outputs = [cout],
            env = {"GOROOT": sdk.root_file.dirname},  # NOTE(#2005): avoid realpath in sandbox
            mnemonic = "GoToolchainBinaryCompile",
        )
    else:
        cmd = "{go} tool compile -o {cout} -trimpath=$PWD {srcs}".format(
            go = sdk.go.path,
            cout = cout.path,
            srcs = " ".join([f.path for f in ctx.files.srcs]),
        )
        ctx.actions.run_shell(
            command = cmd,
            inputs = sdk.libs + sdk.headers + sdk.tools + ctx.files.srcs + [sdk.go],
            outputs = [cout],
            env = {"GOROOT": sdk.root_file.dirname},  # NOTE(#2005): avoid realpath in sandbox
            mnemonic = "GoToolchainBinaryCompile",
        )

    out = ctx.actions.declare_file(name)
    largs = ctx.actions.args()
    largs.add_all(["tool", "link"])
    largs.add("-o", out)
    largs.add(cout)
    ctx.actions.run(
        executable = sdk.go,
        arguments = [largs],
        inputs = sdk.libs + sdk.headers + sdk.tools + [cout],
        outputs = [out],
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
