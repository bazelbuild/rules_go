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
load("@io_bazel_rules_go//go/private:actions/asm.bzl", "emit_asm")
load("@io_bazel_rules_go//go/private:actions/compile.bzl", "emit_compile")
load("@io_bazel_rules_go//go/private:actions/cover.bzl", "emit_cover")
load("@io_bazel_rules_go//go/private:actions/library.bzl", "emit_library")
load("@io_bazel_rules_go//go/private:actions/link.bzl", "emit_link")
load("@io_bazel_rules_go//go/private:actions/pack.bzl", "emit_pack")

def _go_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
      name = ctx.label.name,
      sdk = ctx.attr.sdk,
      env = {
          "GOROOT": ctx.attr.root.path,
          "GOOS": ctx.attr.goos,
          "GOARCH": ctx.attr.goarch,
      },
      actions = struct(
          asm = emit_asm,
          compile = emit_compile,
          cover = emit_cover,
          library = emit_library,
          link = emit_link,
          pack = emit_pack,
      ),
      paths = struct(
        root = ctx.attr.root,
      ),
      tools = struct(
        go = ctx.executable.go,
        asm = ctx.executable._asm,
        compile = ctx.executable._compile,
        link = ctx.executable._link,
        cgo = ctx.executable._cgo,
        test_generator = ctx.executable._test_generator,
        extract_package = ctx.executable._extract_package,
      ),
      flags = struct(
        compile = ctx.attr._go_toolchain_flags.compile_flags,
        link = ctx.attr.link_flags,
        link_cgo = ctx.attr.cgo_link_flags,
      ),
      data = struct(
        tools = ctx.files.tools,
        stdlib = ctx.files.stdlib,
        headers = ctx.attr.headers,
        crosstool = ctx.files._crosstool,
      ),
      external_linker = ctx.attr._external_linker,
  )]

def _get_linker():
  # TODO: return None if there is no cpp fragment available
  # This is not possible right now, we need a new bazel feature
  return Label("//go/toolchain:external_linker")

def _asm(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:asm")

def _compile(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:compile")

def _link(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:link")

def _cgo(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:cgo")

def _test_generator(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:generate_test_main")

def _extract_package(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/extract_package")

go_toolchain = rule(
    _go_toolchain_impl,
    attrs = {
        "sdk": attr.string(mandatory = True),
        "root": attr.label(mandatory = True),
        "go": attr.label(mandatory = True, allow_files = True, single_file = True, executable = True, cfg = "host"),
        "tools": attr.label(mandatory = True, allow_files = True),
        "stdlib": attr.label(mandatory = True, allow_files = True),
        "headers": attr.label(mandatory = True),
        "link_flags": attr.string_list(default = []),
        "cgo_link_flags": attr.string_list(default = []),
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "bootstrap": attr.bool(mandatory = True),
        # Tools, missing from bootstrap toolchains
        "_asm": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _asm),
        "_compile": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _compile),
        "_link": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _link),
        "_cgo": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _cgo),
        "_test_generator": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _test_generator),
        "_extract_package": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _extract_package),
        # Hidden internal attributes
        "_crosstool": attr.label(default=Label("//tools/defaults:crosstool")),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
        "_external_linker": attr.label(default=_get_linker),
    },
)
"""Declares a go toolchain for use.
This is used when porting the rules_go to a new platform.
"""

def _go_toolchain_flags(ctx):
    return struct(
        compile_flags = ctx.attr.compile_flags,
    )

go_toolchain_flags = rule(
    _go_toolchain_flags,
    attrs = {
        "compile_flags": attr.string_list(mandatory=True),
    },
)

def _external_linker_impl(ctx):
  cpp = ctx.fragments.cpp
  features = ctx.features
  options = (cpp.compiler_options(features) +
        cpp.unfiltered_compiler_options(features) +
        cpp.link_options +
        cpp.mostly_static_link_options(features, False))
  return struct(
      compiler_executable = cpp.compiler_executable,
      options = options,
      c_options = cpp.c_options,
  )

_external_linker = rule(
    _external_linker_impl,
    attrs = {},
    fragments = ["cpp"],
)

def external_linker():
    _external_linker(name="external_linker")
