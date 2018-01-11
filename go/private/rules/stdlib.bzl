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
load("@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)

_STDLIB_BUILD = """
load("@io_bazel_rules_go//go/private:rules/stdlib.bzl", "stdlib")

stdlib(
    name = "{name}",
    goos = "{goos}",
    goarch = "{goarch}",
    race = {race},
    pure = {pure},
    visibility = ["//visibility:public"],
)
"""

def _stdlib_impl(ctx):
  go = go_context(ctx)
  pkg = ctx.actions.declare_directory("pkg")
  root_file = ctx.actions.declare_file("ROOT")
  files = [root_file, go.go, pkg]
  args = go.args(go)
  args.add(["-out", root_file.dirname])
  if ctx.attr.race:
    args.add("-race")
  ctx.actions.write(root_file, "")
  go.actions.run(
      inputs = go.sdk_files + go.sdk_tools + [go.package_list, root_file],
      outputs = [pkg],
      mnemonic = "GoStdlib",
      executable = ctx.executable._stdlib_builder,
      arguments = [args],
  )

  return [
      DefaultInfo(
          files = depset(files),
      ),
      GoStdLib(
          root_file = root_file,
          mode = go.mode,
          libs = [pkg],
          headers = [pkg],
          files = files,
      ),
  ]

stdlib = rule(
    _stdlib_impl,
    attrs = {
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "race": attr.bool(mandatory = True),
        "pure": attr.bool(mandatory = True),
        "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_bootstrap_context_data")),
        "_stdlib_builder": attr.label(
            executable = True,
            cfg = "host",
            default = Label("@io_bazel_rules_go//go/tools/builders:stdlib"),
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:bootstrap_toolchain"],
)

def _go_stdlib_impl(ctx):
    ctx.file("BUILD.bazel", _STDLIB_BUILD.format(
        name = ctx.name,
        goos = ctx.attr.goos,
        goarch = ctx.attr.goarch,
        race = ctx.attr.race,
        pure = ctx.attr.pure,
    ))

go_stdlib = repository_rule(
    implementation = _go_stdlib_impl,
    attrs = {
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "race": attr.bool(mandatory = True),
        "pure": attr.bool(mandatory = True),
    },
)
"""See /go/toolchains.rst#go-sdk for full documentation."""
