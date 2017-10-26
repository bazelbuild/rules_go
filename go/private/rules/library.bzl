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
    "go_importpath",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "CgoInfo",
    "GoLibrary",
    "GoEmbed",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)

def _go_library_impl(ctx):
  """Implements the go_library() rule."""
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  embed = ctx.attr.embed
  if ctx.attr.library:
    embed = embed + [ctx.attr.library]
  cgo_info = ctx.attr.cgo_info[CgoInfo] if ctx.attr.cgo_info else None
  mode = get_mode(ctx)
  golib, goembed, goarchive = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_info = cgo_info,
      embed = embed,
      want_coverage = ctx.coverage_instrumented(),
      importpath = go_importpath(ctx),
      importable = True,
  )
  cgo_exports = ctx.attr.cgo_info[CgoInfo].exports if ctx.attr.cgo_info else depset()

  return [
      golib, goembed, goarchive,
      DefaultInfo(
          files = depset([goarchive.file]),
          runfiles = golib.runfiles,
      ),
      OutputGroupInfo(
          cgo_exports = cgo_exports,
      ),
  ]

go_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "embed": attr.label_list(providers = [GoEmbed]),
        "gc_goopts": attr.string_list(),
        "cgo_info": attr.label(providers = [CgoInfo]),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""See go/core.rst#go_library for full documentation."""
