load("@io_bazel_rules_go//go/private:common.bzl",
    "go_importpath",
    "RACE_MODE",
    "NORMAL_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "get_library",
    "GoLibrary",
    "GoEmbed",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)

def _go_proto_library_impl(ctx):
  go_proto_toolchain = ctx.toolchains[ctx.attr._toolchain]
  importpath = go_importpath(ctx)
  go_srcs = go_proto_toolchain.compile(ctx,
    proto_toolchain = ctx.toolchains["@io_bazel_rules_go//proto:proto"],
    go_proto_toolchain = go_proto_toolchain,
    lib = ctx.attr.proto,
    importpath = importpath,
  )
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  golib, goembed = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      srcs = go_srcs,
      deps = ctx.attr.deps + go_proto_toolchain.deps,
      embed = ctx.attr.embed,
      want_coverage = ctx.coverage_instrumented(),
      importpath = importpath,
  )
  return [
      golib, goembed,
      DefaultInfo(
          files = depset([get_library(golib, NORMAL_MODE)]),
          runfiles = golib.runfiles,
      ),
      OutputGroupInfo(
          race = depset([get_library(golib, RACE_MODE)]),
      ),
  ]

go_proto_library = rule(
    _go_proto_library_impl,
    attrs = {
        "proto": attr.label(mandatory=True, providers=["proto"]),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "embed": attr.label_list(providers = [GoEmbed]),
        "gc_goopts": attr.string_list(),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
        "_toolchain": attr.string(default = "@io_bazel_rules_go//proto:go_proto"),
    },
    toolchains = [
        "@io_bazel_rules_go//go:toolchain",
        "@io_bazel_rules_go//proto:proto",
        "@io_bazel_rules_go//proto:go_proto",
    ],
)
"""
go_proto_library is a rule that takes a proto_library (in the proto
attribute) and produces a go library for it.
"""

go_grpc_library = rule(
    _go_proto_library_impl,
    attrs = {
        "proto": attr.label(mandatory=True, providers=["proto"]),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "embed": attr.label_list(providers = [GoEmbed]),
        "gc_goopts": attr.string_list(),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_toolchain": attr.string(default = "@io_bazel_rules_go//proto:go_grpc"),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    toolchains = [
        "@io_bazel_rules_go//go:toolchain",
        "@io_bazel_rules_go//proto:proto",
        "@io_bazel_rules_go//proto:go_grpc",
    ],
)
"""
go_grpc_library is a rule that takes a proto_library (in the proto
attribute) and produces a go library that includes grpc services for it.
"""

def proto_register_toolchains():
  native.register_toolchains(
    "@io_bazel_rules_go//proto:proto",
    "@io_bazel_rules_go//proto:go_proto",
    "@io_bazel_rules_go//proto:go_grpc",
  )
