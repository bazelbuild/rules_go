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
    "link_modes",
    "NORMAL_MODE",
    "RACE_MODE",
    "STATIC_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoBinary",
)

def emit_binary(ctx, go_toolchain,
    name="",
    importpath = "",
    srcs = (),
    deps = (),
    golibs = (),
    cgo_info = None,
    embed = (),
    gc_linkopts = (),
    x_defs = {},
    default = None):
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
      golibs = golibs,
  )

  executables = {}
  extension = "" # TODO: .exe on windows

  if default:
    executables["default"] = default

  for mode in link_modes:
    executable = ctx.new_file(name + "." + mode + extension)
    executables[mode] = executable

  for mode, executable in executables.items():
    if mode == "default":
        # work out what the default mode should be
        if "race" in ctx.features:
            mode = RACE_MODE
        elif "static" in ctx.features:
            mode = STATIC_MODE
        else:
            mode = NORMAL_MODE

    go_toolchain.actions.link(
        ctx,
        go_toolchain = go_toolchain,
        library=golib,
        mode=mode,
        executable=executable,
        gc_linkopts=gc_linkopts,
        x_defs=x_defs,
    )

  return [
      golib,
      GoBinary(**executables),
  ]
