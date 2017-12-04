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
    "declare_file",
    "sets",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
)

GoProtoCompiler = provider()

_protoc_prefix = "protoc-gen-"

def go_proto_compile(ctx, compiler, lib, importpath):
  go_srcs = []
  outpath = None
  for proto in lib.proto.direct_sources:
    out = declare_file(ctx, path=importpath+"/"+proto.basename[:-len(".proto")], ext=compiler.suffix)
    go_srcs.append(out)
    if outpath == None:
        outpath = out.dirname[:-len(importpath)]
  plugin_base_name = compiler.plugin.basename
  if plugin_base_name.startswith(_protoc_prefix):
    plugin_base_name = plugin_base_name[len(_protoc_prefix):]
  args = ctx.actions.args()
  args.add(["-protoc", compiler.protoc.path])
  args.add([
      "--importpath", importpath,
      "--{}_out={}:{}".format(plugin_base_name, ",".join(compiler.options), outpath),
      "--plugin={}={}".format(compiler.plugin.basename, compiler.plugin.path),
      "--descriptor_set_in", ":".join(
          [s.path for s in lib.proto.transitive_descriptor_sets])
  ])
  for out in go_srcs:
      args.add(["--expected", out])
  args.add(lib.proto.direct_sources, map_fn=_all_proto_paths)
  ctx.actions.run(
      inputs = sets.union([
          compiler.go_protoc,
          compiler.protoc,
          compiler.plugin,
      ], lib.proto.transitive_descriptor_sets),
      outputs = go_srcs,
      progress_message = "Generating into %s" % go_srcs[0].dirname,
      mnemonic = "GoProtocGen",
      executable = compiler.go_protoc,
      arguments = [args],
  )
  return go_srcs

def _all_proto_paths(protos):
  return [_proto_path(proto) for proto in protos]

def _proto_path(proto):
  """
  The proto path is not really a file path
  It's the path to the proto that was seen when the descriptor file was generated.
  """
  path = proto.path
  root = proto.root.path
  ws = proto.owner.workspace_root
  if path.startswith(root): path = path[len(root):]
  if path.startswith("/"): path = path[1:]
  if path.startswith(ws): path = path[len(ws):]
  if path.startswith("/"): path = path[1:]
  return path


def _go_proto_compiler_impl(ctx):
  return [GoProtoCompiler(
      deps = ctx.attr.deps,
      compile = go_proto_compile,
      options = ctx.attr.options,
      suffix = ctx.attr.suffix,
      go_protoc = ctx.file._go_protoc,
      protoc = ctx.file._protoc,
      plugin = ctx.file.plugin,
  )]

go_proto_compiler = rule(
    _go_proto_compiler_impl,
    attrs = {
        "deps": attr.label_list(providers = [GoLibrary]),
        "options": attr.string_list(),
        "suffix": attr.string(default = ".pb.go"),
        "plugin": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = Label("@com_github_golang_protobuf//protoc-gen-go"),
        ),
        "_go_protoc":  attr.label(
            allow_files=True,
            single_file=True,
            executable = True,
            cfg = "host",
            default=Label("@io_bazel_rules_go//go/tools/builders:go-protoc"),
        ),
        "_protoc": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = Label("@com_github_google_protobuf//:protoc"),
        ),
    }
)
