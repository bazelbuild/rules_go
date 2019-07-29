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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@io_bazel_rules_go//go:def.bzl",
    "GoLibrary",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

GoProtoCompiler = provider()

def go_proto_compile(go, compiler, protos, imports, importpath):
    go_srcs = []
    outpath = None
    proto_paths = {}
    desc_sets = []
    for proto in protos:
        desc_sets.append(proto.transitive_descriptor_sets)
        for src in proto.check_deps_sources.to_list():
            path = proto_path(src, proto)
            if path in proto_paths:
                if proto_paths[path] != src:
                    fail("proto files {} and {} have the same import path, {}".format(
                        src.path,
                        proto_paths[path].path,
                        path,
                    ))
                continue
            proto_paths[path] = src

            out = go.declare_file(
                go,
                path = importpath + "/" + src.basename[:-len(".proto")],
                ext = compiler.suffix,
            )
            go_srcs.append(out)
            if outpath == None:
                outpath = out.dirname[:-len(importpath)]

    transitive_descriptor_sets = depset(direct = [], transitive = desc_sets)

    args = go.actions.args()
    args.add("-protoc", compiler.protoc)
    args.add("-importpath", importpath)
    args.add("-out_path", outpath)
    args.add("-plugin", compiler.plugin)

    # TODO(jayconrod): can we just use go.env instead?
    args.add_all(compiler.options, before_each = "-option")
    if compiler.import_path_option:
        args.add_all([importpath], before_each = "-option", format_each = "import_path=%s")
    args.add_all(transitive_descriptor_sets, before_each = "-descriptor_set")
    args.add_all(go_srcs, before_each = "-expected")
    args.add_all(imports, before_each = "-import")
    args.add_all(proto_paths.keys())
    go.actions.run(
        inputs = depset(
            direct = [
                compiler.go_protoc,
                compiler.protoc,
                compiler.plugin,
            ],
            transitive = [transitive_descriptor_sets],
        ),
        outputs = go_srcs,
        progress_message = "Generating into %s" % go_srcs[0].dirname,
        mnemonic = "GoProtocGen",
        executable = compiler.go_protoc,
        arguments = [args],
        env = go.env,
    )
    return go_srcs

def proto_path(src, proto):
    """proto_path returns the string used to import the proto. This is the proto
    source path within its repository, adjusted by import_prefix and
    strip_import_prefix.

    Args:
        src: the proto source File.
        proto: the ProtoInfo provider.

    Returns:
        An import path string.
    """
    if not hasattr(proto, "proto_source_root"):
        # Legacy path. Remove when Bazel minimum version >= 0.21.0.
        path = src.path
        root = src.root.path
        ws = src.owner.workspace_root
        if path.startswith(root):
            path = path[len(root):]
        if path.startswith("/"):
            path = path[1:]
        if path.startswith(ws):
            path = path[len(ws):]
        if path.startswith("/"):
            path = path[1:]
        return path

    if proto.proto_source_root == ".":
        # true if proto sources were generated
        prefix = src.root.path + "/"
    elif proto.proto_source_root.startswith(src.root.path):
        # sometimes true when import paths are adjusted with import_prefix
        prefix = proto.proto_source_root + "/"
    else:
        # usually true when paths are not adjusted
        prefix = paths.join(src.root.path, proto.proto_source_root) + "/"
    if not src.path.startswith(prefix):
        # sometimes true when importing multiple adjusted protos
        return src.path
    return src.path[len(prefix):]

def _go_proto_compiler_impl(ctx):
    go = go_context(ctx)
    library = go.new_library(go)
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    return [
        GoProtoCompiler(
            deps = ctx.attr.deps,
            compile = go_proto_compile,
            options = ctx.attr.options,
            suffix = ctx.attr.suffix,
            go_protoc = ctx.executable._go_protoc,
            protoc = ctx.executable._protoc,
            plugin = ctx.executable.plugin,
            valid_archive = ctx.attr.valid_archive,
            import_path_option = ctx.attr.import_path_option,
        ),
        library,
        source,
    ]

go_proto_compiler = go_rule(
    _go_proto_compiler_impl,
    attrs = {
        "deps": attr.label_list(providers = [GoLibrary]),
        "options": attr.string_list(),
        "suffix": attr.string(default = ".pb.go"),
        "valid_archive": attr.bool(default = True),
        "import_path_option": attr.bool(default = False),
        "plugin": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "host",
            default = "@com_github_golang_protobuf//protoc-gen-go",
        ),
        "_go_protoc": attr.label(
            executable = True,
            cfg = "host",
            default = "@io_bazel_rules_go//go/tools/builders:go-protoc",
        ),
        "_protoc": attr.label(
            executable = True,
            cfg = "host",
            default = "@com_google_protobuf//:protoc",
        ),
    },
)
