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
    "split_srcs",
    "pkg_dir",
    "declare_file",
)
load("@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load("@io_bazel_rules_go//go/private:rules/binary.bzl", "gc_linkopts")
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
)
load("@io_bazel_rules_go//go/private:rules/helpers.bzl",
    "get_archive",
    "new_go_library",
    "library_to_source",
)
load("@io_bazel_rules_go//go/private:actions/action.bzl",
    "add_go_env",
)
load("@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "go_archive_aspect",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)

def _testmain_library_to_source(ctx, attr, source):
  source["deps"] = source["deps"] + [attr.library]

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  mode = get_mode(ctx, ctx.attr._go_toolchain_flags)
  archive = get_archive(ctx.attr.library)
  stdlib = go_toolchain.stdlib.get(ctx, go_toolchain, archive.source.mode)

  # now generate the main function
  if ctx.attr.rundir:
    if ctx.attr.rundir.startswith("/"):
      run_dir = ctx.attr.rundir
    else:
      run_dir = pkg_dir(ctx.label.workspace_root, ctx.attr.rundir)
  else:
    run_dir = pkg_dir(ctx.label.workspace_root, ctx.label.package)

  main_go = declare_file(ctx, "testmain.go")
  arguments = ctx.actions.args()
  add_go_env(arguments, stdlib, archive.source.mode)
  arguments.add([
      '--package',
      archive.source.library.importpath,
      '--rundir',
      run_dir,
      '--output',
      main_go,
  ])
  for var in archive.cover_vars:
    arguments.add(["-cover", var])
  go_srcs = split_srcs(archive.source.srcs).go
  arguments.add(go_srcs)
  ctx.actions.run(
      inputs = go_srcs,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go_toolchain.tools.test_generator,
      arguments = [arguments],
      env = {
          "RUNDIR" : ctx.label.package,
      },
  )

  # Now compile the test binary itself
  test_library = new_go_library(ctx,
      resolver=_testmain_library_to_source,
      srcs=[main_go],
      importable=False,
  )
  test_source = library_to_source(ctx, ctx.attr, test_library, mode)
  test_archive, executable = go_toolchain.actions.binary(ctx, go_toolchain,
      name = ctx.label.name,
      source = test_source,
      gc_linkopts = gc_linkopts(ctx),
      x_defs=ctx.attr.x_defs,
  )

  runfiles = ctx.runfiles(files = [executable])
  runfiles = runfiles.merge(archive.runfiles)
  runfiles = runfiles.merge(test_archive.runfiles)
  return [
      DefaultInfo(
          files = depset([executable]),
          runfiles = runfiles,
          executable = executable,
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
        "pure": attr.string(values=["on", "off", "auto"], default="auto"),
        "static": attr.string(values=["on", "off", "auto"], default="auto"),
        "race": attr.string(values=["on", "off", "auto"], default="auto"),
        "msan": attr.string(values=["on", "off", "auto"], default="auto"),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_toolchain_flags": attr.label(default=Label("@io_bazel_rules_go//go/private:go_toolchain_flags")),
    },
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""See go/core.rst#go_test for full documentation."""
