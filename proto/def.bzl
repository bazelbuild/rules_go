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
    "@io_bazel_rules_go//go:def.bzl",
    "GoLibrary",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "sets",
)
load(
    "@io_bazel_rules_go//proto:compiler.bzl",
    "GoProtoCompiler",
    "proto_path",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "INFERRED_PATH",
)

GoProtoImports = provider()

def get_imports(attr):
    direct = []
    if hasattr(attr, "proto"):
        direct = [
            "{}={}".format(proto_path(src), attr.importpath)
            for src in attr.proto.proto.direct_sources
        ]
    deps = getattr(attr, "deps", []) + getattr(attr, "embed", [])
    transitive = [
        dep[GoProtoImports].imports
        for dep in deps
        if GoProtoImports in dep
    ]
    return depset(direct = direct, transitive = transitive)

def _go_proto_aspect_impl(target, ctx):
    imports = get_imports(ctx.rule.attr)
    return [GoProtoImports(imports = imports)]

_go_proto_aspect = aspect(
    _go_proto_aspect_impl,
    attr_aspects = [
        "deps",
        "embed",
    ],
)

def _proto_library_to_source(go, attr, source, merge):
    if attr.compiler:
        merge(source, attr.compiler)
        return
    for compiler in attr.compilers:
        merge(source, compiler)

def _go_proto_library_impl(ctx):
    go = go_context(ctx)
    if go.pathtype == INFERRED_PATH:
        fail("importpath must be specified in this library or one of its embedded libraries")
    if ctx.attr.compiler:
        #TODO: print("DEPRECATED: compiler attribute on {}, use compilers instead".format(ctx.label))
        compilers = [ctx.attr.compiler]
    else:
        compilers = ctx.attr.compilers
    go_srcs = []
    valid_archive = False
    for c in compilers:
        compiler = c[GoProtoCompiler]
        if compiler.valid_archive:
            valid_archive = True
        go_srcs.extend(compiler.compile(
            go,
            compiler = compiler,
            proto = ctx.attr.proto.proto,
            imports = get_imports(ctx.attr),
            importpath = go.importpath,
        ))
    library = go.new_library(
        go,
        resolver = _proto_library_to_source,
        srcs = go_srcs,
    )
    source = go.library_to_source(go, ctx.attr, library, False)
    if not valid_archive:
        return [library, source]
    archive = go.archive(go, source)
    return [
        library,
        source,
        archive,
        DefaultInfo(
            files = depset([archive.data.file]),
            runfiles = archive.runfiles,
        ),
    ]

go_proto_library = go_rule(
    _go_proto_library_impl,
    attrs = {
        "proto": attr.label(
            mandatory = True,
            providers = ["proto"],
        ),
        "deps": attr.label_list(
            providers = [GoLibrary],
            aspects = [_go_proto_aspect],
        ),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "compiler": attr.label(providers = [GoProtoCompiler]),
        "compilers": attr.label_list(
            providers = [GoProtoCompiler],
            default = ["@io_bazel_rules_go//proto:go_proto"],
        ),
    },
)
"""
go_proto_library is a rule that takes a proto_library (in the proto
attribute) and produces a go library for it.
"""

def go_grpc_library(**kwargs):
    # TODO: Deprecate once gazelle generates just go_proto_library
    go_proto_library(compilers = ["@io_bazel_rules_go//proto:go_grpc"], **kwargs)

def proto_register_toolchains():
    print("You no longer need to call proto_register_toolchains(), it does nothing")
