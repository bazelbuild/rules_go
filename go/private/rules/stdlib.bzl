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

load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoStdLib",
)
load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

def _stdlib_library_to_source(go, attr, source, merge):
  pkg = go.declare_directory(go, "pkg")
  root_file = go.declare_file(go, "ROOT")
  files = [root_file, go.go, pkg]
  args = go.args(go)
  args.add(["-out", root_file.dirname])
  if go.mode.race:
    args.add("-race")
  go.actions.write(root_file, "")
  go.actions.run(
      inputs = go.sdk_files + go.sdk_tools + [go.package_list, root_file],
      outputs = [pkg],
      mnemonic = "GoStdlib",
      executable = attr._stdlib_builder.files.to_list()[0],
      arguments = [args],
  )
  source["stdlib"] = GoStdLib(
      root_file = root_file,
      mode = go.mode,
      libs = [pkg],
      headers = [pkg],
      files = files,
  )

def _stdlib_impl(ctx):
  go = go_context(ctx)
  library = go.new_library(go, resolver = _stdlib_library_to_source)
  source = go.library_to_source(go, ctx.attr, library, False)
  return [source, library]

stdlib = go_rule(
    _stdlib_impl,
    bootstrap = True,
    attrs = {
        "_stdlib_builder": attr.label(
            executable = True,
            cfg = "host",
            default = Label("@io_bazel_rules_go//go/tools/builders:stdlib"),
        ),
    },
)
