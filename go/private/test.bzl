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

load("@io_bazel_rules_go//go/private:common.bzl", "get_go_toolchain", "go_filetype", "split_srcs", "pkg_dir")
load("@io_bazel_rules_go//go/private:library.bzl", "emit_library_actions", "go_importpath", "emit_go_compile_action", "get_gc_goopts", "emit_go_pack_action")
load("@io_bazel_rules_go//go/private:binary.bzl", "emit_go_link_action", "gc_linkopts")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoBinary")

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go_toolchain = get_go_toolchain(ctx)
  golib, _ = emit_library_actions(ctx,
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_object = None,
      library = ctx.attr.library,
      want_coverage = False,
      importpath = go_importpath(ctx),
  )

  if ctx.attr.rundir:
    if ctx.attr.rundir.startswith("/"):
      run_dir = ctx.attr.rundir
    else:
      run_dir = pkg_dir(ctx.label.workspace_root, ctx.attr.rundir)
  else:
    run_dir = pkg_dir(ctx.label.workspace_root, ctx.label.package)

  coverage_args = []
  if ctx.attr.library:
    coverage_filename_map = ctx.attr.library[GoLibrary].coverage_filename_map
    if coverage_filename_map:
      coverage_json = struct(**coverage_filename_map).to_json()
      coverage_args = ["--coverage_filename_map", coverage_json]

  go_srcs = list(split_srcs(golib.srcs).go)
  main_go = ctx.new_file(ctx.label.name + "_main_test.go")
  ctx.action(
      inputs = go_srcs,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go_toolchain.test_generator,
      arguments = [
          '--package',
          golib.importpath,
          '--rundir',
          run_dir,
          '--output',
          main_go.path,
      ] + coverage_args + [src.path for src in go_srcs],
      env = dict(go_toolchain.env, RUNDIR=ctx.label.package)
  )

  main_lib, _ = emit_library_actions(ctx,
      srcs = [main_go],
      deps = [],
      cgo_object = None,
      library = None,
      want_coverage = False,
      importpath = ctx.label.name + "~testmain~",
      golibs = [golib],
  )

  go_library_paths = golib.transitive_go_library_paths
  go_libraries = golib.transitive_go_libraries
  linkopts = gc_linkopts(ctx)
  if "race" in ctx.features:
    go_library_paths=golib.transitive_go_library_paths_race
    go_libraries=golib.transitive_go_libraries_race
    linkopts += ["-race"]

  emit_go_link_action(
      ctx,
      transitive_go_library_paths=go_library_paths,
      transitive_go_libraries=go_libraries,
      cgo_deps=golib.transitive_cgo_deps,
      libs=depset([main_lib.library]),
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
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
        "_go_prefix": attr.label(default = Label(
            "//:go_prefix",
            relative_to_caller_repository = True,
        )),
    },
    executable = True,
    fragments = ["cpp"],
    test = True,
)
