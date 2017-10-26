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

load("@io_bazel_rules_go//go/private:mode.bzl",
    "mode_string",
    "get_mode",
)

def emit_binary(ctx, go_toolchain,
    name="",
    importpath = "",
    srcs = (),
    deps = (),
    cgo_info = None,
    embed = (),
    gc_linkopts = (),
    x_defs = {},
    executable = None,
    wrap = None):
  """See go/toolchains.rst#binary for full documentation."""

  if name == "": fail("name is a required parameter")

  mode = get_mode(ctx)
  golib, goembed, goarchive = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      srcs = srcs,
      deps = deps,
      cgo_info = cgo_info,
      embed = embed,
      importpath = importpath,
      importable = False,
  )

  go_toolchain.actions.link(ctx,
      go_toolchain = go_toolchain,
      archive=goarchive,
      mode=mode,
      executable=executable,
      gc_linkopts=gc_linkopts,
      x_defs=x_defs,
  )

  return golib
