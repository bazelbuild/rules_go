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
    "@io_bazel_rules_go//go/private:common.bzl",
    "paths",
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
    cgo = {cgo},
    visibility = ["//visibility:public"],
)
"""

def _stdlib_impl(ctx):
  go = go_context(ctx)
  src = ctx.actions.declare_directory("src")
  pkg = ctx.actions.declare_directory("pkg")
  root_file = ctx.actions.declare_file("ROOT")
  goroot = root_file.path[:-(len(root_file.basename)+1)]
  files = [root_file, go.go, pkg]
  ctx.actions.write(root_file, "")
  cc_path = go.cgo_tools.compiler_executable
  if not paths.is_absolute(cc_path):
    cc_path = "$(pwd)/" + cc_path
  cgo = ctx.attr.cgo
  env = {
      "GOROOT": "$(pwd)/{}".format(goroot),
      "GOROOT_FINAL": "GOROOT",
      "GOOS": ctx.attr.goos,
      "GOARCH": ctx.attr.goarch,
      "CGO_ENABLED": "1" if cgo else "0",
      "CC": cc_path,
      "CXX": cc_path,
      "COMPILER_PATH": go.cgo_tools.compiler_path,
      "CGO_CPPFLAGS": " ".join(go.cgo_tools.compiler_options),
      "CGO_LDFLAGS": " ".join(go.cgo_tools.linker_options),
  }
  inputs = go.sdk_files + go.sdk_tools + [root_file]
  install_args = []
  if ctx.attr.race:
    install_args.append("-race")
  install_args = " ".join(install_args)

  ctx.actions.run_shell(
      inputs = inputs,
      outputs = [src, pkg],
      mnemonic = "GoStdlib",
      command = " && ".join([
          "export " + " ".join(['{}="{}"'.format(key, value) for key, value in env.items()]),
          "export PATH=$PATH:$(cd \"$COMPILER_PATH\" && pwd)",
          "mkdir -p {}".format(src.path),
          "mkdir -p {}".format(pkg.path),
          "cp -rf {}/src/* {}/".format(go.root, src.path),
          "cp -rf {}/pkg/tool {}/".format(go.root, pkg.path),
          "cp -rf {}/pkg/include {}/".format(go.root, pkg.path),
          "{} install -asmflags \"-trimpath $(pwd)\" {} std".format(go.go.path, install_args),
          "{} install -asmflags \"-trimpath $(pwd)\" {} runtime/cgo".format(go.go.path, install_args),
         ])
  )
  return [
      DefaultInfo(
          files = depset([root_file, go.go, src, pkg]),
      ),
      GoStdLib(
          root_file = root_file,
          goos = ctx.attr.goos,
          goarch = ctx.attr.goarch,
          race = ctx.attr.race,
          pure = not ctx.attr.cgo,
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
        "cgo": attr.bool(mandatory = True),
        "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_bootstrap_context_data")),
    },
    toolchains = ["@io_bazel_rules_go//go:bootstrap_toolchain"],
    fragments = ["cpp"],
)

def _go_stdlib_impl(ctx):
    ctx.file("BUILD.bazel", _STDLIB_BUILD.format(
        name = ctx.name,
        goos = ctx.attr.goos,
        goarch = ctx.attr.goarch,
        race = ctx.attr.race,
        cgo = ctx.attr.cgo,
    ))

go_stdlib = repository_rule(
    implementation = _go_stdlib_impl,
    attrs = {
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "race": attr.bool(mandatory = True),
        "cgo": attr.bool(mandatory = True),
    },
)
"""See /go/toolchains.rst#go-sdk for full documentation."""
