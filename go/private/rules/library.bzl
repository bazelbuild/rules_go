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
    "go_filetype",
    "go_importpath",
    "RACE_MODE",
    "NORMAL_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl", 
    "GoLibrary", 
    "get_library",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)

def _go_library_impl(ctx):
  """Implements the go_library() rule."""
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object
  golib, cgolib = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_object = cgo_object,
      library = ctx.attr.library,
      want_coverage = ctx.coverage_instrumented(),
      importpath = go_importpath(ctx),
  )

  return [
      golib,
      cgolib,
      DefaultInfo(
          files = depset([get_library(golib, NORMAL_MODE)]),
          runfiles = golib.runfiles,
      ),
      OutputGroupInfo(
          race = depset([get_library(golib, RACE_MODE)]),
      ),
  ]

go_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "cgo_object": attr.label(
            providers = [
                "cgo_obj",
                "cgo_deps",
            ],
        ),
        "_go_prefix": attr.label(default = go_prefix_default),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
