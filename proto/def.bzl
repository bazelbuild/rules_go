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

load("@io_bazel_rules_go//go/private:common.bzl",
    "go_importpath",
    "sets",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
)
load("@io_bazel_rules_go//go/private:rules/helpers.bzl",
    "new_go_library",
    "library_to_source",
    "get_source",
    "merge_embed",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//proto:compiler.bzl",
    "GoProtoCompiler",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)

GoProtoImports = provider()

def get_imports(attr):
  imports = []
  if hasattr(attr, "proto"):
    imports.append(["{}={}".format(src.path, attr.importpath) for src in attr.proto.proto.direct_sources])
  imports.extend([dep[GoProtoImports].imports for dep in attr.deps])
  imports.extend([dep[GoProtoImports].imports for dep in attr.embed])
  return sets.union(*imports)

def _go_proto_aspect_impl(target, ctx):
  return [GoProtoImports(imports = get_imports(ctx.rule.attr))]

_go_proto_aspect = aspect(
    _go_proto_aspect_impl,
    attr_aspects = ["deps", "embed"],
)

def _proto_library_to_source(ctx, attr, source):
  compiler = attr.compiler[GoProtoCompiler]
  merge_embed(source, attr.compiler)

def _go_proto_library_impl(ctx):
  mode = get_mode(ctx, ctx.attr._go_toolchain_flags)
  compiler = ctx.attr.compiler[GoProtoCompiler]
  importpath = go_importpath(ctx)
  go_srcs = compiler.compile(ctx,
    compiler = compiler,
    proto = ctx.attr.proto.proto,
    imports = get_imports(ctx.attr),
    importpath = importpath,
  )
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  library = new_go_library(ctx,
      resolver=_proto_library_to_source,
      srcs=go_srcs,
  )
  source = library_to_source(ctx, ctx.attr, library, mode)
  archive = go_toolchain.actions.archive(ctx, go_toolchain, source)

  return [
      library, source, archive,
      DefaultInfo(
          files = depset([archive.data.file]),
          runfiles = archive.runfiles,
      ),
  ]

go_proto_library = rule(
    _go_proto_library_impl,
    attrs = {
        "proto": attr.label(mandatory=True, providers=["proto"]),
        "deps": attr.label_list(providers = [GoLibrary], aspects = [_go_proto_aspect]),
        "importpath": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "compiler": attr.label(providers = [GoProtoCompiler], default = "@io_bazel_rules_go//proto:go_proto"),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    toolchains = [
        "@io_bazel_rules_go//go:toolchain",
    ],
)
"""
go_proto_library is a rule that takes a proto_library (in the proto
attribute) and produces a go library for it.
"""

def go_grpc_library(**kwargs):
  # TODO: Deprecate once gazelle generates just go_proto_library
  go_proto_library(compiler="@io_bazel_rules_go//proto:go_grpc", **kwargs)

def proto_register_toolchains():
  print("You no longer need to call proto_register_toolchains(), it does nothing")
