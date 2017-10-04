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

load("@io_bazel_rules_go//go/private:common.bzl",
    "compile_modes",
    "go_filetype",
    "go_importpath",
    "NORMAL_MODE",
    "RACE_MODE",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "CgoInfo",
    "GoLibrary",
    "GoBinary",
    "GoEmbed",
)

def _go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  embed = ctx.attr.embed
  if ctx.attr.library:
    embed = embed + [ctx.attr.library]

  cgo_info = ctx.attr.cgo_info[CgoInfo] if ctx.attr.cgo_info else None
  golib, gobinary = go_toolchain.actions.binary(ctx, go_toolchain,
      name = ctx.label.name,
      importpath = go_importpath(ctx),
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_info = cgo_info,
      embed = embed,
      gc_linkopts = gc_linkopts(ctx),
      x_defs = ctx.attr.x_defs,
      default = ctx.outputs.executable,
  )
  return [
      golib, gobinary,
      DefaultInfo(
          files = depset([gobinary.default]),
          runfiles = golib.runfiles,
      ),
      OutputGroupInfo(
          normal = depset([gobinary.normal]),
          static = depset([gobinary.static]),
          race = depset([gobinary.race]),
      ),
  ]

go_binary = rule(
    _go_binary_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "embed": attr.label_list(providers = [GoEmbed]),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "x_defs": attr.string_dict(),
        "cgo_info": attr.label(providers = [CgoInfo]),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    executable = True,
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""See go/core.rst#go_binary for full documentation."""

def gc_linkopts(ctx):
  gc_linkopts = [ctx.expand_make_variables("gc_linkopts", f, {})
                 for f in ctx.attr.gc_linkopts]
  return gc_linkopts
