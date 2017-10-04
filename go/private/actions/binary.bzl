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
    "NORMAL_MODE",
    "RACE_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoBinary",
)

def emit_binary(ctx, go_toolchain,
    name="",
    importpath = "",
    srcs = (),
    deps = (),
    cgo_info = None,
    embed = (),
    gc_linkopts = (),
    x_defs = {}):
  """See go/toolchains.rst#binary for full documentation."""

  if name == "": fail("name is a required parameter")

  golib, _ = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      srcs = srcs,
      deps = deps,
      cgo_info = cgo_info,
      embed = embed,
      importpath = importpath,
      importable = False,
  )

  # Default (dynamic) linking
  race_executable = ctx.new_file(name + ".race")
  for mode in compile_modes:
    executable = ctx.outputs.executable
    if mode == RACE_MODE:
      executable = race_executable
    go_toolchain.actions.link(
        ctx,
        go_toolchain = go_toolchain,
        library=golib,
        mode=mode,
        executable=executable,
        gc_linkopts=gc_linkopts,
        x_defs=x_defs,
    )

  # Static linking (in the 'static' output group)
  static_linkopts = [
      "-linkmode", "external",
      "-extldflags", "-static",
  ]
  static_executable = ctx.new_file(name + ".static")
  go_toolchain.actions.link(
      ctx,
      go_toolchain = go_toolchain,
      library=golib,
      mode=NORMAL_MODE,
      executable=static_executable,
      gc_linkopts=gc_linkopts + static_linkopts,
      x_defs=x_defs,
  )

  return [
      golib,
      GoBinary(
          executable = ctx.outputs.executable,
          static = static_executable,
          race = race_executable,
      ),
  ]
