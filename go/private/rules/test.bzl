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
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//go/private:rules/binary.bzl", "gc_linkopts")
load("@io_bazel_rules_go//go/private:providers.bzl",
    "CgoInfo",
    "GoLibrary",
    "GoEmbed",
)
load("@io_bazel_rules_go//go/private:actions/action.bzl",
    "action_with_go_env",
)
load("@io_bazel_rules_go//go/private:actions/archive.bzl",
    "go_archive_aspect",
)

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  mode = get_mode(ctx)
  golib = ctx.attr.library[GoLibrary]

  # now generate the main function
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

  action_with_go_env(ctx, go_toolchain, mode,
      inputs = go_srcs,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go_toolchain.tools.test_generator,
      arguments = arguments + [src.path for src in go_srcs],
      env = {
          "RUNDIR" : ctx.label.package,
      },
  )

  # Now compile the test binary itself
  executable = ctx.outputs.executable
  main_lib = go_toolchain.actions.binary(ctx, go_toolchain,
      name = ctx.label.name,
      srcs = [main_go],
      deps = [ctx.attr.library],
      importpath = ctx.label.name + "~testmain~",
      gc_linkopts = gc_linkopts(ctx),
      executable = executable,
      x_defs=ctx.attr.x_defs,
  )

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(collect_data = True, files = [executable])
  runfiles = runfiles.merge(golib.runfiles)
  return [
      DefaultInfo(
          files = depset([executable]),
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
        "deps": attr.label_list(providers = [GoLibrary], aspects = [go_archive_aspect]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary], aspects = [go_archive_aspect]),
        "embed": attr.label_list(providers = [GoEmbed], aspects = [go_archive_aspect]),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        "cgo_info": attr.label(providers = [CgoInfo]),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""See go/core.rst#go_test for full documentation."""
