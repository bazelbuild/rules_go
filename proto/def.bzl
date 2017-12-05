load("@io_bazel_rules_go//go/private:common.bzl",
    "go_importpath",
    "sets",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoSourceList",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)
load("@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "collect_src",
)
load("@io_bazel_rules_go//proto:compiler.bzl",
    "GoProtoCompiler",
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

def _go_proto_library_impl(ctx):
  compiler = ctx.attr.compiler[GoProtoCompiler]
  importpath = go_importpath(ctx)
  go_srcs = compiler.compile(ctx,
    compiler = compiler,
    proto = ctx.attr.proto.proto,
    imports = get_imports(ctx.attr),
    importpath = importpath,
  )
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  mode = get_mode(ctx, ctx.attr._go_toolchain_flags)
  gosource = collect_src(
      ctx, srcs = go_srcs,
      deps = ctx.attr.deps + compiler.deps,
  )
  golib, goarchive = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      source = gosource,
      importpath = importpath,
      importable = True,
  )
  return [
      golib, gosource, goarchive,
      DefaultInfo(
          files = depset([goarchive.data.file]),
          runfiles = goarchive.runfiles,
      ),
  ]

go_proto_library = rule(
    _go_proto_library_impl,
    attrs = {
        "proto": attr.label(mandatory=True, providers=["proto"]),
        "deps": attr.label_list(providers = [GoLibrary], aspects = [_go_proto_aspect]),
        "importpath": attr.string(),
        "embed": attr.label_list(providers = [GoSourceList]),
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
