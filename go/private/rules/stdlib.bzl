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
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_C_SHARED",
)

def _stdlib_library_to_source(go, attr, source, merge):
  pkg = go.declare_directory(go, "pkg")
  root_file = go.declare_file(go, "ROOT")
  filter_buildid = attr._filter_buildid_builder.files.to_list()[0]
  files = [root_file, go.go, pkg]
  args = go.args(go)
  args.add(["-out", root_file.dirname])
  if go.mode.race:
    args.add("-race")
  if go.mode.link == LINKMODE_C_SHARED:
    args.add("-shared")
  args.add(["-filter_buildid", filter_buildid.path])
  go.actions.write(root_file, "")
  env = go.env
  env.update({
      "CC": go.cgo_tools.compiler_executable,
      "CGO_CPPFLAGS": " ".join(go.cgo_tools.compiler_options),
      "CGO_CFLAGS": " ".join(go.cgo_tools.c_options),
      "CGO_LDFLAGS": " ".join(go.cgo_tools.linker_options),
  })
  go.actions.run(
      inputs = go.sdk_files + go.sdk_tools + go.crosstool + [filter_buildid, go.package_list, root_file],
      outputs = [pkg],
      mnemonic = "GoStdlib",
      executable = attr._stdlib_builder.files.to_list()[0],
      arguments = [args],
      env = env,
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
        "_filter_buildid_builder": attr.label(
            executable = True,
            cfg = "host",
            default = Label("@io_bazel_rules_go//go/tools/builders:filter_buildid"),
        ),
    },
)
