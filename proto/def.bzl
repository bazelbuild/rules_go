# Copyright 2017 The Bazel Authors. All rights reserved.
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
    "//go:def.bzl",
    "GoLibrary",
    "GoSource",
    "go_context",
)
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)
load(
    "//proto:compiler.bzl",
    "GoProtoCompiler",
    "proto_path",
)
load(
    "//go/private:go_toolchain.bzl",
    "GO_TOOLCHAIN",
)
load(
    "//go/private:providers.bzl",
    "INFERRED_PATH",
)
load(
    "//go/private/rules:transition.bzl",
    "non_go_tool_transition",
)
load(
    "@rules_proto//proto:defs.bzl",
    "ProtoInfo",
)

GoProtoImports = provider()

def get_imports(attr):
    proto_deps = []

    # ctx.attr.proto is a one-element array since there is a Starlark transition attached to it.
    if hasattr(attr, "proto") and attr.proto and types.is_list(attr.proto) and ProtoInfo in attr.proto[0]:
        proto_deps = [attr.proto[0]]
    elif hasattr(attr, "protos"):
        proto_deps = [d for d in attr.protos if ProtoInfo in d]
    else:
        proto_deps = []

    direct = dict()
    for dep in proto_deps:
        for src in dep[ProtoInfo].check_deps_sources.to_list():
            direct["{}={}".format(proto_path(src, dep[ProtoInfo]), attr.importpath)] = True

    deps = getattr(attr, "deps", []) + getattr(attr, "embed", [])
    transitive = [
        dep[GoProtoImports].imports
        for dep in deps
        if GoProtoImports in dep
    ]
    return depset(direct = direct.keys(), transitive = transitive)

def _go_proto_aspect_impl(_target, ctx):
    imports = get_imports(ctx.rule.attr)
    return [GoProtoImports(imports = imports)]

_go_proto_aspect = aspect(
    _go_proto_aspect_impl,
    attr_aspects = [
        "deps",
        "embed",
    ],
)

def _proto_library_to_source(_go, attr, source, merge):
    if attr.compiler:
        compilers = [attr.compiler]
    else:
        compilers = attr.compilers
    for compiler in compilers:
        if GoSource in compiler:
            merge(source, compiler[GoSource])

def _go_proto_library_impl(ctx):
    go = go_context(ctx)
    if go.pathtype == INFERRED_PATH:
        fail("importpath must be specified in this library or one of its embedded libraries")
    if ctx.attr.compiler:
        #TODO: print("DEPRECATED: compiler attribute on {}, use compilers instead".format(ctx.label))
        compilers = [ctx.attr.compiler]
    else:
        compilers = ctx.attr.compilers

    if ctx.attr.proto:
        #TODO: print("DEPRECATED: proto attribute on {}, use protos instead".format(ctx.label))
        if ctx.attr.protos:
            fail("Either proto or protos (non-empty) argument must be specified, but not both")

        # ctx.attr.proto is a one-element array since there is a Starlark transition attached to it.
        proto_deps = [ctx.attr.proto[0]]
    else:
        if not ctx.attr.protos:
            fail("Either proto or protos (non-empty) argument must be specified")
        proto_deps = ctx.attr.protos

    go_srcs = []
    valid_archive = False

    for c in compilers:
        compiler = c[GoProtoCompiler]
        if compiler.valid_archive:
            valid_archive = True
        go_srcs.extend(compiler.compile(
            go,
            compiler = compiler,
            protos = [d[ProtoInfo] for d in proto_deps],
            imports = get_imports(ctx.attr),
            importpath = go.importpath,
        ))
    library = go.new_library(
        go,
        resolver = _proto_library_to_source,
        srcs = go_srcs,
    )
    source = go.library_to_source(go, ctx.attr, library, False)
    providers = [library, source]
    output_groups = {
        "go_generated_srcs": go_srcs,
    }
    if valid_archive:
        archive = go.archive(go, source)
        output_groups["compilation_outputs"] = [archive.data.file]
        providers.extend([
            archive,
            DefaultInfo(
                files = depset([archive.data.file]),
                runfiles = archive.runfiles,
            ),
        ])
    return providers + [OutputGroupInfo(**output_groups)]

go_proto_library = rule(
    implementation = _go_proto_library_impl,
    attrs = {
        "proto": attr.label(
            cfg = non_go_tool_transition,
            providers = [ProtoInfo],
        ),
        "protos": attr.label_list(
            cfg = non_go_tool_transition,
            providers = [ProtoInfo],
            default = [],
        ),
        "deps": attr.label_list(
            providers = [GoLibrary],
            aspects = [_go_proto_aspect],
        ),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "importpath_aliases": attr.string_list(),  # experimental, undocumented
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "compiler": attr.label(providers = [GoProtoCompiler]),
        "compilers": attr.label_list(
            providers = [GoProtoCompiler],
            default = ["//proto:go_proto"],
        ),
        "_go_context_data": attr.label(
            default = "//:go_context_data",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    toolchains = [GO_TOOLCHAIN],
)
# go_proto_library is a rule that takes a proto_library (in the proto
# attribute) and produces a go library for it.

def go_grpc_library(**kwargs):
    # TODO: Deprecate once gazelle generates just go_proto_library
    go_proto_library(compilers = [Label("//proto:go_grpc")], **kwargs)

def proto_register_toolchains():
    print("You no longer need to call proto_register_toolchains(), it does nothing")
