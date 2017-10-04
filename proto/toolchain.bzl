
_protoc_prefix = "protoc-gen-"

def _emit_proto_compile(ctx, proto_toolchain, go_proto_toolchain, lib, importpath):
  go_srcs = []
  outpath = None
  for proto in lib.proto.direct_sources:
    out = ctx.new_file(ctx.label.name + "/" + importpath + "/" + proto.basename[:-len(".proto")] + ".pb.go")
    go_srcs += [out]
    if outpath == None:
        outpath = out.dirname[:-len(importpath)]
  plugin_base_name = go_proto_toolchain.plugin.basename
  if plugin_base_name.startswith(_protoc_prefix):
    plugin_base_name = plugin_base_name[len(_protoc_prefix):]
  args= [
      "--{}_out={}:{}".format(plugin_base_name, ",".join(go_proto_toolchain.options), outpath),
      "--plugin={}={}".format(go_proto_toolchain.plugin.basename, go_proto_toolchain.plugin.path),
      "--descriptor_set_in", ":".join(
          [s.path for s in lib.proto.transitive_descriptor_sets])
  ]
  args += [proto.short_path for proto in lib.proto.direct_sources]
  ctx.action(
      inputs = [
          proto_toolchain.protoc,
          go_proto_toolchain.plugin,
      ] + lib.proto.transitive_descriptor_sets.to_list(),
      outputs = go_srcs,
      progress_message = "Generating into %s" % go_srcs[0].dirname,
      mnemonic = "GoProtocGen",
      executable = proto_toolchain.protoc,
      arguments = args,
  )
  return go_srcs

def _proto_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
      protoc = ctx.file._protoc,
  )]

proto_toolchain = rule(
    _proto_toolchain_impl,
    attrs = {
        "_protoc": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("@com_github_google_protobuf//:protoc")),
    },
)

def _go_proto_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
      plugin = ctx.file.plugin,
      deps = ctx.attr.deps,
      options = ctx.attr.options,
      compile = _emit_proto_compile,
  )]

go_proto_toolchain = rule(
    _go_proto_toolchain_impl,
    attrs = {
        "deps": attr.label_list(),
        "options": attr.string_list(),
        "plugin": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("@com_github_golang_protobuf//protoc-gen-go")),
    },
)
