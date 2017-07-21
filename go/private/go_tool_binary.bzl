# Copyright 2017 The Bazel Authors. All rights reserved.
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
load('//go/private:go_toolchain.bzl', 'go_toolchain_core_attrs')

BOOTSTRAP_TOOLCHAIN_TYPE = "@io_bazel_rules_go//go:bootstrap_toolchain"

def _go_bootstrap_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
      type = Label(BOOTSTRAP_TOOLCHAIN_TYPE),
      name = ctx.label.name,
      root = ctx.attr.root.path,
      go = ctx.executable.go,
      tools = ctx.files.tools,
      stdlib = ctx.files.stdlib,
  )]

go_bootstrap_toolchain = rule(
    _go_bootstrap_toolchain_impl,
    attrs = go_toolchain_core_attrs,
)

def _go_tool_binary_impl(ctx):
  toolchain = ctx.toolchains[BOOTSTRAP_TOOLCHAIN_TYPE]
  ctx.action(
      inputs = ctx.files.srcs + toolchain.tools + toolchain.stdlib,
      outputs = [ctx.outputs.executable],
      command = [
          toolchain.go.path,
          "build",
          "-o",
          ctx.outputs.executable.path,
      ] + [src.path for src in ctx.files.srcs],
      mnemonic = "GoBuildTool",
      env = {
          "GOROOT": toolchain.root,
      },
  )

go_tool_binary = rule(
    _go_tool_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = FileType([".go"])),
    },
    executable = True,
    toolchains = [BOOTSTRAP_TOOLCHAIN_TYPE],
)
"""Builds a Go program using `go build`.

This is used instead of `go_binary` for tools that are executed inside
actions emitted by the go rules. This avoids a bootstrapping problem. This
is very limited and only supports sources in the main package with no
dependencies outside the standard library.

Args:
  name: A unique name for this rule.
  srcs: list of pure Go source files. No cgo allowed.
"""
