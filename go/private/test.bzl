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

load("//go/private:common.bzl", "get_go_toolchain", "emit_generate_params_action", "go_filetype")
load("//go/private:library.bzl", "emit_library_actions", "go_importpath", "emit_go_compile_action", "get_gc_goopts", "emit_go_pack_action")
load("//go/private:binary.bzl", "emit_go_link_action", "gc_linkopts")

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
  go_import = go_importpath(ctx)

  cmds = [
      'UNFILTERED_TEST_FILES=(%s)' %
          ' '.join(["'%s'" % f.path for f in lib_result.go_sources]),
      'FILTERED_TEST_FILES=()',
      'while read -r line; do',
      '  if [ -n "$line" ]; then',
      '    FILTERED_TEST_FILES+=("$line")',
      '  fi',
      'done < <(\'%s\' -cgo "${UNFILTERED_TEST_FILES[@]}")' %
          go_toolchain.filter_tags.path,
      ' '.join([
          "'%s'" % go_toolchain.test_generator.path,
          '--package',
          go_import,
          '--output',
          "'%s'" % main_go.path,
          '"${FILTERED_TEST_FILES[@]}"',
      ]),
  ]
  f = emit_generate_params_action(
      cmds, ctx, ctx.label.name + ".GoTestGenTest.params")
  inputs = (list(lib_result.go_sources) + list(go_toolchain.tools) +
            [f, go_toolchain.filter_tags, go_toolchain.test_generator])
  ctx.action(
      inputs = inputs,
      outputs = [main_go],
      command = f.path,
      mnemonic = "GoTestGenTest",
      env = dict(go_toolchain.env, RUNDIR=ctx.label.package))

  emit_go_compile_action(
    ctx,
    sources=depset([main_go]),
    libs=lib_result.transitive_go_libraries,
    libpaths=lib_result.transitive_go_library_paths,
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
    gc_linkopts=gc_linkopts(ctx))

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(files = [ctx.outputs.executable])
  runfiles = runfiles.merge(lib_result.runfiles)
  return struct(
      files = set([ctx.outputs.executable]),
      runfiles = runfiles,
  )

go_test = rule(
    _go_test_impl,
    attrs = {
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(
            providers = [
                "transitive_go_library_paths",
                "transitive_go_libraries",
                "transitive_cgo_deps",
            ],
        ),
        "importpath": attr.string(),
        "library": attr.label(
            providers = [
                "direct_deps",
                "go_sources",
                "asm_sources",
                "cgo_object",
                "gc_goopts",
            ],
        ),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "x_defs": attr.string_dict(),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
        "_go_prefix": attr.label(default=Label("//:go_prefix", relative_to_caller_repository = True)),
    },
    executable = True,
    fragments = ["cpp"],
    test = True,
)

