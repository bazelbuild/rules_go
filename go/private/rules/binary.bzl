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
    "//go/private:context.bzl",
    "go_context",
)
load(
    "//go/private:common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
)
load(
    "//go/private:providers.bzl",
    "GoLibrary",
    "GoSDK",
)
load(
    "//go/private/rules:transition.bzl",
    "go_transition_rule",
)
load(
    "//go/private:mode.bzl",
    "LINKMODE_C_ARCHIVE",
    "LINKMODE_C_SHARED",
    "LINKMODE_PLUGIN",
    "LINKMODE_SHARED",
)
load(
    "//go/private:rpath.bzl",
    "rpath",
)

_EMPTY_DEPSET = depset([])

def new_cc_import(
        go,
        hdrs = _EMPTY_DEPSET,
        defines = _EMPTY_DEPSET,
        local_defines = _EMPTY_DEPSET,
        dynamic_library = None,
        static_library = None,
        alwayslink = False,
        linkopts = []):
    if dynamic_library:
        linkopts = linkopts + rpath.flags(go, dynamic_library)
    return CcInfo(
        compilation_context = cc_common.create_compilation_context(
            defines = defines,
            local_defines = local_defines,
            headers = hdrs,
            includes = depset([hdr.root.path for hdr in hdrs.to_list()]),
        ),
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([
                cc_common.create_linker_input(
                    owner = go.label,
                    libraries = depset([
                        cc_common.create_library_to_link(
                            actions = go.actions,
                            cc_toolchain = go.cgo_tools.cc_toolchain,
                            feature_configuration = go.cgo_tools.feature_configuration,
                            dynamic_library = dynamic_library,
                            static_library = static_library,
                            alwayslink = alwayslink,
                        ),
                    ]),
                    user_link_flags = depset(linkopts),
                ),
            ]),
        ),
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

    providers = [
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

    # If the binary's linkmode is c-archive or c-shared, expose CcInfo
    if go.cgo_tools and go.mode.link in (LINKMODE_C_ARCHIVE, LINKMODE_C_SHARED):
        cc_import_kwargs = {
            "linkopts": {
                "darwin": [],
                "windows": ["-mthreads"],
            }.get(go.mode.goos, ["-pthread"]),
        }
        cgo_exports = archive.cgo_exports.to_list()
        if cgo_exports:
            header = ctx.actions.declare_file("{}.h".format(name))
            ctx.actions.symlink(
                output = header,
                target_file = cgo_exports[0],
            )
            cc_import_kwargs["hdrs"] = depset([header])
        if go.mode.link == LINKMODE_C_SHARED:
            cc_import_kwargs["dynamic_library"] = executable
        elif go.mode.link == LINKMODE_C_ARCHIVE:
            cc_import_kwargs["static_library"] = executable
            cc_import_kwargs["alwayslink"] = True
        ccinfo = new_cc_import(go, **cc_import_kwargs)
        ccinfo = cc_common.merge_cc_infos(
            cc_infos = [ccinfo] + [d[CcInfo] for d in source.cdeps],
        )
        providers.append(ccinfo)

    return providers

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
        "embedsrcs": attr.label_list(allow_files = True),
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
            executable = bat,
            inputs = sdk.libs + sdk.headers + sdk.tools + ctx.files.srcs + [sdk.go],
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
