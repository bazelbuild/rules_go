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
load("@io_bazel_rules_go//go/private:actions/binary.bzl", "emit_binary")
load("@io_bazel_rules_go//go/private:actions/compile.bzl", "emit_compile")
load("@io_bazel_rules_go//go/private:actions/cover.bzl", "emit_cover")
load("@io_bazel_rules_go//go/private:actions/library.bzl", "emit_library")
load("@io_bazel_rules_go//go/private:actions/link.bzl", "emit_link")
load("@io_bazel_rules_go//go/private:actions/pack.bzl", "emit_pack")

def _go_toolchain_impl(ctx):
  tmp = ctx.attr._root.path + "/tmp"
  return [platform_common.ToolchainInfo(
      name = ctx.label.name,
      sdk = ctx.attr.sdk,
      env = {
          "GOROOT": ctx.attr._root.path,
          "GOOS": ctx.attr.goos,
          "GOARCH": ctx.attr.goarch,
          "TMP": tmp,
      },
      actions = struct(
          asm = emit_asm,
          binary = emit_binary,
          compile = emit_compile,
          cover = emit_cover,
          library = emit_library,
          link = emit_link,
          pack = emit_pack,
      ),
      paths = struct(
          root = ctx.attr._root,
          tmp = tmp,
      ),
      tools = struct(
          go = ctx.executable._go,
          asm = ctx.executable._asm,
          compile = ctx.executable._compile,
          pack = ctx.executable._pack,
          link = ctx.executable._link,
          cgo = ctx.executable._cgo,
          test_generator = ctx.executable._test_generator,
          extract_package = ctx.executable._extract_package,
      ),
      flags = struct(
          compile = (),
          link = ctx.attr.link_flags,
          link_cgo = ctx.attr.cgo_link_flags,
      ),
      data = struct(
          tools = ctx.files._tools,
          stdlib = ctx.files._stdlib,
          headers = ctx.attr._headers,
          crosstool = ctx.files._crosstool,
      ),
      external_linker = ctx.attr._external_linker,
  )]

def _go(sdk):
  return Label("@{}//:go".format(sdk))

def _tools(sdk):
  return Label("@{}//:tools".format(sdk))

def _stdlib(sdk, goos, goarch):
  return Label("@{}//:stdlib_{}_{}".format(sdk, goos, goarch))

def _headers(sdk):
  return Label("@{}//:headers".format(sdk))

def _root(sdk):
  return Label("@{}//:root".format(sdk))

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

def _pack(bootstrap):
  if bootstrap:
    return None
  return Label("//go/tools/builders:pack")

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

_go_toolchain = rule(
    _go_toolchain_impl,
    attrs = {
        # Minimum requirements to specify a toolchain
        "sdk": attr.string(mandatory = True),
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        # Optional extras to a toolchain
        "link_flags": attr.string_list(default = []),
        "cgo_link_flags": attr.string_list(default = []),
        "bootstrap": attr.bool(default = False),
        # Tools, missing from bootstrap toolchains
        "_asm": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _asm),
        "_compile": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _compile),
        "_pack": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _pack),
        "_link": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _link),
        "_cgo": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _cgo),
        "_test_generator": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _test_generator),
        "_extract_package": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default = _extract_package),
        # Hidden internal attributes
        "_go": attr.label(allow_files = True, single_file = True, executable = True, cfg = "host", default=_go),
        "_tools": attr.label(allow_files = True, default = _tools),
        "_stdlib": attr.label(allow_files = True, default = _stdlib),
        "_headers": attr.label(default=_headers),
        "_root": attr.label(default=_root),
        "_crosstool": attr.label(default=Label("//tools/defaults:crosstool")),
        "_external_linker": attr.label(default=_get_linker),
    },
)

def go_toolchain(name, target, host=None, constraints=[], **kwargs):
  """See go/toolchains.rst#go-toolchain for full documentation."""

  if not host: host = target
  goos, _, goarch = target.partition("_")
  target_constraints = constraints + [
    "@io_bazel_rules_go//go/toolchain:" + goos,
    "@io_bazel_rules_go//go/toolchain:" + goarch,
  ]
  host_goos, _, host_goarch = host.partition("_")
  exec_constraints = [
      "@io_bazel_rules_go//go/toolchain:" + host_goos,
      "@io_bazel_rules_go//go/toolchain:" + host_goarch,
  ]

  impl_name = name + "-impl"
  _go_toolchain(
      name = impl_name,
      goos = goos,
      goarch = goarch,
      bootstrap = False,
      tags = ["manual"],
      **kwargs
  )
  native.toolchain(
      name = name,
      toolchain_type = "@io_bazel_rules_go//go:toolchain",
      exec_compatible_with = exec_constraints,
      target_compatible_with = target_constraints,
      toolchain = ":"+impl_name,
  )

  if host == target:
    # If not cross, register a bootstrap toolchain
    name = name + "-bootstrap"
    impl_name = name + "-impl"
    _go_toolchain(
        name = impl_name,
        goos = goos,
        goarch = goarch,
        bootstrap = True,
        tags = ["manual"],
        visibility = ["//visibility:public"],
        **kwargs
    )
    native.toolchain(
        name = name,
        toolchain_type = "@io_bazel_rules_go//go:bootstrap_toolchain",
        exec_compatible_with = exec_constraints,
        target_compatible_with = target_constraints,
        toolchain = ":"+impl_name,
    )

def _go_toolchain_flags(ctx):
    return struct(
        compilation_mode = ctx.attr.compilation_mode,
        strip = ctx.attr.strip,
    )

go_toolchain_flags = rule(
    _go_toolchain_flags,
    attrs = {
        "compilation_mode": attr.string(mandatory=True),
        "strip": attr.string(mandatory=True),
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
