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

load("@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)

def _go_info_script_impl(ctx):
  go = go_context(ctx)
  out = go.declare_file(go, ext=".bash")
  args = go.args(go)
  args.add(["-script", "-out", out])
  ctx.actions.run(
      inputs = [],
      outputs = [out],
      mnemonic = "GoInfo",
      executable = ctx.executable._go_info,
      arguments = [args],
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
            default="@io_bazel_rules_go//go/tools/builders:info"),
        "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_context_data")),
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