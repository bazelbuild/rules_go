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

def _constraint_rule_impl(ctx):
    return struct()

_constraint = rule(
    _constraint_rule_impl,
    attrs = {},
)

def toolchain_type(name):
    # Should be platform_common.toolchain_type
    return name

def toolchain(type, **args):
    # Should be platform_common.toolchain
    return struct(type=type, **args)

ConstraintValueInfo = [] # Shoull be platform_common.ConstraintValueInfo

def platform(name, constraint_values):
    return

def constraint_setting(name):
    _constraint(name = name)

def constraint_value(name, setting):
    _constraint(name = name)

#### End of special compatability functions
###########################################

go_toolchain_type = toolchain_type('go_toolchain')

def _go_toolchain_impl(ctx):
  return toolchain(
      go_toolchain_type,
      exec_compatible_with = ctx.attr.exec_compatible_with,
      target_compatible_with = ctx.attr.target_compatible_with,
      env = {
          "GOROOT": ctx.attr.root.path,
          "GOOS": ctx.attr.goos,
          "GOARCH": ctx.attr.goarch,
      },
      go = ctx.executable.go,
      src = ctx.files.src,
      include = ctx.file.include,
      all_files = ctx.files.all_files,
      filter_tags = ctx.executable.filter_tags,
      filter_exec = ctx.executable.filter_exec,
      asm = ctx.executable.asm,
      test_generator = ctx.executable.test_generator,
      extract_package = ctx.executable.extract_package,
      link_flags = ctx.attr.link_flags,
      cgo_link_flags = ctx.attr.cgo_link_flags,
  )

go_toolchain_core_attrs = {
    "exec_compatible_with": attr.label_list(providers = [ConstraintValueInfo]),
    "target_compatible_with": attr.label_list(providers = [ConstraintValueInfo]),
    "root": attr.label(),
    "go": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host"),
    "src": attr.label(allow_files = True),
    "include": attr.label(allow_files = True, single_file = True),
    "all_files": attr.label(allow_files = True),
}

go_toolchain_attrs = go_toolchain_core_attrs + {
    "is_cross": attr.bool(),
    "goos": attr.string(),
    "goarch": attr.string(),
    "filter_tags": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/filter_tags")),
    "filter_exec": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/filter_exec")),
    "asm": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/builders:asm")),
    "test_generator": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools:generate_test_main")),
    "extract_package": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=Label("//go/tools/extract_package")),
    "link_flags": attr.string_list(default=[]),
    "cgo_link_flags": attr.string_list(default=[]),
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
