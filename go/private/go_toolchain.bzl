# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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
"""
Toolchain rules used by go.
"""

#TODO: Remove this once all users (kubernetes) no longer use it
def get_go_toolchain(ctx):
    return ctx.toolchains["@io_bazel_rules_go//go:toolchain"]

def _go_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
      type = Label("@io_bazel_rules_go//go:toolchain"),
      env = {
          "GOROOT": ctx.attr.root.path,
          "GOOS": ctx.attr.goos,
          "GOARCH": ctx.attr.goarch,
      },
      name = ctx.label.name,
      sdk = ctx.attr.sdk,
      go = ctx.executable.go,
      root = ctx.attr.root,
      tools = ctx.files.tools,
      stdlib = ctx.files.stdlib,
      headers = ctx.attr.headers,
      asm = ctx.executable.asm,
      compile = ctx.executable.compile,
      link = ctx.executable.link,
      cgo = ctx.executable.cgo,
      test_generator = ctx.executable.test_generator,
      extract_package = ctx.executable.extract_package,
      link_flags = ctx.attr.link_flags,
      cgo_link_flags = ctx.attr.cgo_link_flags,
      crosstool = ctx.files.crosstool,
  )]

go_toolchain_core_attrs = {
    "sdk": attr.string(mandatory = True),
    "root": attr.label(mandatory = True),
    "go": attr.label(mandatory = True, allow_files = True, single_file = True, executable = True, cfg = "host"),
    "tools": attr.label(mandatory = True, allow_files = True),
    "stdlib": attr.label(mandatory = True, allow_files = True),
    "headers": attr.label(mandatory = True),
    "link_flags": attr.string_list(default=[]),
    "cgo_link_flags": attr.string_list(default=[]),
    "goos": attr.string(mandatory = True),
    "goarch": attr.string(mandatory = True),
}

go_toolchain_attrs = go_toolchain_core_attrs + {
    "asm": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:asm")),
    "compile": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:compile")),
    "link": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:link")),
    "cgo": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:cgo")),
    "test_generator": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:generate_test_main")),
    "extract_package": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/extract_package")),
    "crosstool": attr.label(default=Label("//tools/defaults:crosstool")),
}

go_toolchain = rule(
    _go_toolchain_impl,
    attrs = go_toolchain_attrs,
)
"""Declares a go toolchain for use.
This is used when porting the rules_go to a new platform.
Args:
  name: The name of the toolchain instance.
  exec_compatible_with: The set of constraints this toolchain requires to execute.
  target_compatible_with: The set of constraints for the outputs built with this toolchain.
  go: The location of the `go` binary.
"""
