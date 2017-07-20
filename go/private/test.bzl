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

load("@io_bazel_rules_go//go/private:common.bzl", "get_go_toolchain", "go_filetype", "pkg_dir")
load("@io_bazel_rules_go//go/private:library.bzl", "emit_library_actions", "go_importpath", "emit_go_compile_action", "get_gc_goopts", "emit_go_pack_action")
load("@io_bazel_rules_go//go/private:binary.bzl", "emit_go_link_action", "gc_linkopts")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoBinary")

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go_toolchain = get_go_toolchain(ctx)
  lib_result = emit_library_actions(ctx,
      sources = depset(ctx.files.srcs),
      deps = ctx.attr.deps,
      cgo_object = None,
      library = ctx.attr.library,
  )
  main_go = ctx.new_file(ctx.label.name + "_main_test.go")
  main_object = ctx.new_file(ctx.label.name + "_main_test.o")
  main_lib = ctx.new_file(ctx.label.name + "_main_test.a")
  run_dir = pkg_dir(ctx.label.workspace_root, ctx.label.package)

  ctx.action(
      inputs = list(lib_result.go_sources),
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go_toolchain.test_generator,
      arguments = [
          '--package',
          lib_result.importpath,
          '--rundir',
          run_dir,
          '--output',
          main_go.path,
      ] + [src.path for src in lib_result.go_sources],
      env = dict(go_toolchain.env, RUNDIR=ctx.label.package)
  )

  if "race" not in ctx.features:
    emit_go_compile_action(
      ctx,
      sources=depset([main_go]),
      libs=[lib_result.library],
      lib_paths=[lib_result.searchpath],
      direct_paths=[lib_result.importpath],
      out_object=main_object,
      gc_goopts=get_gc_goopts(ctx),
    )
    emit_go_pack_action(ctx, main_lib, [main_object])
    emit_go_link_action(
      ctx,
      transitive_go_library_paths=lib_result.transitive_go_library_paths,
      transitive_go_libraries=lib_result.transitive_go_libraries,
      cgo_deps=lib_result.transitive_cgo_deps,
      libs=[main_lib],
      executable=ctx.outputs.executable,
      gc_linkopts=gc_linkopts(ctx),
      x_defs=ctx.attr.x_defs)
  else:
    emit_go_compile_action(
      ctx,
      sources=depset([main_go]),
      libs=[lib_result.race],
      lib_paths=[lib_result.searchpath_race],
      direct_paths=[lib_result.importpath],
      out_object=main_object,
      gc_goopts=get_gc_goopts(ctx) + ["-race"],
    )
    emit_go_pack_action(ctx, main_lib, [main_object])
    emit_go_link_action(
      ctx,
      transitive_go_library_paths=lib_result.transitive_go_library_paths_race,
      transitive_go_libraries=lib_result.transitive_go_libraries_race,
      cgo_deps=lib_result.transitive_cgo_deps,
      libs=[main_lib],
      executable=ctx.outputs.executable,
      gc_linkopts=gc_linkopts(ctx) + ["-race"],
      x_defs=ctx.attr.x_defs)

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(files = [ctx.outputs.executable])
  runfiles = runfiles.merge(lib_result.runfiles)
  return [
      GoBinary(
          executable = ctx.outputs.executable,
      ),
      DefaultInfo(
          files = set([ctx.outputs.executable]),
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
