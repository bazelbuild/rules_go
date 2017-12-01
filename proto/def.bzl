load("@io_bazel_rules_go//go/private:common.bzl",
    "go_importpath",
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

def _go_proto_library_impl(ctx):
  compiler = ctx.attr.compiler[GoProtoCompiler]
  importpath = go_importpath(ctx)
  go_srcs = compiler.compile(ctx,
    compiler = compiler,
    lib = ctx.attr.proto,
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
        "deps": attr.label_list(providers = [GoLibrary]),
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
    go_proto_library(compiler="@io_bazel_rules_go//proto:go_grpc", **kwargs)

def proto_register_toolchains():
  print("You no longer need to call proto_register_toolchains(), it does nothing")
