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

####################################
#### Special compatability functions
#TODO(toolchains): Remove this entire block when real toolchains arrive

def _constraint_rule_impl(ctx):
    return struct(i_am_a_constraint=True)

_constraint = rule(
    _constraint_rule_impl,
    attrs = {},
)

def toolchain_type():
    # Should be platform_common.toolchain_type
    return provider()

ConstraintValueInfo = "i_am_a_constraint" # Should be platform_common.ConstraintValueInfo

def platform(name, constraint_values):
    return

def constraint_setting(name):
    _constraint(name = name)

def constraint_value(name, setting):
    _constraint(name = name)

#### End of special compatability functions
###########################################

go_toolchain_type = toolchain_type()

def _go_toolchain_impl(ctx):
  return [go_toolchain_type(
      exec_compatible_with = ctx.attr.exec_compatible_with,
      target_compatible_with = ctx.attr.target_compatible_with,
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
      filter_tags = ctx.executable.filter_tags,
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
    "exec_compatible_with": attr.label_list(providers = [ConstraintValueInfo]),
    "target_compatible_with": attr.label_list(providers = [ConstraintValueInfo]),
    "sdk": attr.string(),
    "root": attr.label(),
    "go": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host"),
    "tools": attr.label(allow_files = True),
    "stdlib": attr.label(allow_files = True),
    "headers": attr.label(),
}

go_toolchain_attrs = go_toolchain_core_attrs + {
    "is_cross": attr.bool(),
    "goos": attr.string(),
    "goarch": attr.string(),
    "filter_tags": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:filter_tags")),
    "asm": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:asm")),
    "compile": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:compile")),
    "link": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:link")),
    "cgo": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:cgo")),
    "test_generator": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:generate_test_main")),
    "extract_package": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/extract_package")),
    "link_flags": attr.string_list(default=[]),
    "cgo_link_flags": attr.string_list(default=[]),
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
