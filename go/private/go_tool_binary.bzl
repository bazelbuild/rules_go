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
load('//go/private:go_toolchain.bzl', 'toolchain_type', 'ConstraintValueInfo', 'go_toolchain_core_attrs')
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary")
load("@io_bazel_rules_go//go/private:library.bzl", "go_importpath")

go_bootstrap_toolchain_type = toolchain_type()

def _go_bootstrap_toolchain_impl(ctx):
  return [go_bootstrap_toolchain_type(
      exec_compatible_with = ctx.attr.exec_compatible_with,
      target_compatible_with = ctx.attr.target_compatible_with,
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
  toolchain = ctx.attr._go_toolchain[go_bootstrap_toolchain_type]
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
  return [
      GoLibrary(
          label = ctx.label,
          importpath = go_importpath(ctx),
          srcs = depset(ctx.files.srcs),
          transitive = (),
      ),
  ]

go_tool_binary = rule(
    _go_tool_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = FileType([".go"])),
        "importpath": attr.string(),
        #TODO(toolchains): Remove toolchain attribute when we switch to real toolchains
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:bootstrap_toolchain")),
        "_go_prefix": attr.label(default=Label("//:go_prefix", relative_to_caller_repository = True)),
    },
    executable = True,
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
