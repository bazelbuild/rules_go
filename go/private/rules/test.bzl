# Copyright 2014 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:common.bzl",
    "go_filetype",
    "go_importpath",
    "split_srcs",
    "pkg_dir",
    "NORMAL_MODE",
    "RACE_MODE",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//go/private:rules/binary.bzl", "gc_linkopts")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoBinary", "GoEmbed")

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  embed = ctx.attr.embed
  if ctx.attr.library:
    embed = embed + [ctx.attr.library]
  golib, _, _ = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_object = None,
      embed = embed,
      want_coverage = False,
      importpath = go_importpath(ctx),
      importable = False,
  )

  if ctx.attr.rundir:
    if ctx.attr.rundir.startswith("/"):
      run_dir = ctx.attr.rundir
    else:
      run_dir = pkg_dir(ctx.label.workspace_root, ctx.attr.rundir)
  else:
    run_dir = pkg_dir(ctx.label.workspace_root, ctx.label.package)

  go_srcs = list(split_srcs(golib.srcs).go)
  main_go = ctx.new_file(ctx.label.name + "_main_test.go")
  arguments = [
      '--package',
      golib.importpath,
      '--rundir',
      run_dir,
      '--output',
      main_go.path,
  ]
  cover_vars = []
  covered_libs = []
  for g in depset([golib]) + golib.transitive:
    if g.cover_vars:
      covered_libs += [g]
      for var in g.cover_vars:
        arguments += ["-cover", "{}={}".format(var, g.importpath)]

  ctx.action(
      inputs = go_srcs,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go_toolchain.tools.test_generator,
      arguments = arguments + [src.path for src in go_srcs],
      env = dict(go_toolchain.env, RUNDIR=ctx.label.package)
  )

  main_lib, _, _ = go_toolchain.actions.library(ctx,
      go_toolchain = go_toolchain,
      srcs = [main_go],
      deps = [],
      cgo_object = None,
      embed = [],
      want_coverage = False,
      importpath = ctx.label.name + "~testmain~",
      importable = False,
      golibs = [golib] + covered_libs,
  )

  mode = NORMAL_MODE
  linkopts = gc_linkopts(ctx)
  if "race" in ctx.features:
    mode = RACE_MODE

  go_toolchain.actions.link(
      ctx,
      go_toolchain = go_toolchain,
      library=main_lib,
      mode=mode,
      executable=ctx.outputs.executable,
      gc_linkopts=linkopts,
      x_defs=ctx.attr.x_defs)

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(files = [ctx.outputs.executable])
  runfiles = runfiles.merge(golib.runfiles)
  return [
      GoBinary(
          executable = ctx.outputs.executable,
      ),
      DefaultInfo(
          files = depset([ctx.outputs.executable]),
          runfiles = runfiles,
      ),
  ]

go_test = rule(
    _go_test_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "embed": attr.label_list(providers = [GoEmbed]),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        "_go_prefix": attr.label(default = go_prefix_default),
    },
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
