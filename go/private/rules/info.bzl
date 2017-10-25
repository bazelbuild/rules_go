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
    "get_mode",
)
load("@io_bazel_rules_go//go/private:actions/action.bzl",
    "action_with_go_env",
)

def _go_info_script_impl(ctx):
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  mode = get_mode(ctx)
  out = ctx.actions.declare_file(ctx.label.name+".bash")
  action_with_go_env(ctx, go_toolchain, mode,
      inputs = [],
      outputs = [out],
      mnemonic = "GoInfo",
      executable = ctx.executable._go_info,
      arguments = ["-script", "-out", out.path],
  )
  return [
      DefaultInfo(
          files = depset([out]),
      ),
  ]

_go_info_script = rule(
    _go_info_script_impl,
    attrs = {
      "_go_info": attr.label(
          allow_files = True,
          single_file = True,
          executable = True,
          cfg = "host",
          default="@io_bazel_rules_go//go/tools/builders:info")
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def go_info():
  _go_info_script(
      name = "go_info_script",
      tags = ["manual"],
  )
  native.sh_binary(
      name = "go_info",
      srcs = ["go_info_script"],
      tags = ["manual"],
  )