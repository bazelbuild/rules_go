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

load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
    "EXPORT_PATH",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "go_filetype",
    "split_srcs",
    "pkg_dir",
)
load(
    "@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load(
    "@io_bazel_rules_go//go/private:rules/binary.bzl",
    "gc_linkopts",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "get_archive",
)
load(
    "@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "go_archive_aspect",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_NORMAL",
)

def _testmain_library_to_source(go, attr, source, merge):
  source["deps"] = source["deps"] + [attr.library]

def _go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  go = go_context(ctx)
  if ctx.attr.linkstamp:
    print("DEPRECATED: linkstamp, please use x_def for all stamping now {}".format(ctx.attr.linkstamp))

  # Compile the library to test with internal white box tests
  internal_library = go.new_library(go, testfilter="exclude")
  internal_source = go.library_to_source(go, ctx.attr, internal_library, ctx.coverage_instrumented())
  internal_archive = go.archive(go, internal_source)
  go_srcs = split_srcs(internal_source.srcs).go

  # Compile the library with the external black box tests
  external_library = go.new_library(go,
      name = internal_library.name + "_test",
      importpath = internal_library.importpath + "_test",
      testfilter="only",
  )
  external_source = go.library_to_source(go, struct(
      srcs = [struct(files=go_srcs)],
      deps = internal_archive.direct + [internal_archive],
      x_defs = ctx.attr.x_defs,
  ), external_library, False)
  external_archive = go.archive(go, external_source)
  external_srcs = split_srcs(external_source.srcs).go

  # now generate the main function
  if ctx.attr.rundir:
    if ctx.attr.rundir.startswith("/"):
      run_dir = ctx.attr.rundir
    else:
      run_dir = pkg_dir(ctx.label.workspace_root, ctx.attr.rundir)
  else:
    run_dir = pkg_dir(ctx.label.workspace_root, ctx.label.package)

  main_go = go.declare_file(go, "testmain.go")
  arguments = go.args(go)
  arguments.add(['-rundir', run_dir, '-output', main_go])
  arguments.add([
      # the l is the alias for the package under test, the l_test must be the
      # same with the test suffix
      '-import', "l="+internal_source.library.importpath,
      '-import', "l_test="+external_source.library.importpath])
  arguments.add(external_archive.cover_vars, before_each="-cover")
  arguments.add(go_srcs, before_each="-src", format="l=%s")
  ctx.actions.run(
      inputs = go_srcs,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      executable = go.builders.test_generator,
      arguments = [arguments],
      env = {
          "RUNDIR" : ctx.label.package,
      },
  )

  # Now compile the test binary itself
  test_library = GoLibrary(
      name = go._ctx.label.name + "~testmain",
      label = go._ctx.label,
      importpath = "testmain",
      importmap = "testmain",
      pathtype = EXPORT_PATH,
      resolve = None,
  )
  test_source = go.library_to_source(go, struct(
      srcs = [struct(files=[main_go])],
      deps = external_archive.direct + [external_archive],
  ), test_library, False)
  test_archive, executable = go.binary(go,
      name = ctx.label.name,
      source = test_source,
      gc_linkopts = gc_linkopts(ctx),
      linkstamp=ctx.attr.linkstamp,
      version_file=ctx.version_file,
      info_file=ctx.info_file,
  )

  runfiles = ctx.runfiles(files = [executable])
  runfiles = runfiles.merge(test_archive.runfiles)
  return [
      DefaultInfo(
          files = depset([executable]),
          runfiles = runfiles,
          executable = executable,
      ),
]

go_test = go_rule(
    _go_test_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "embed": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "pure": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "static": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "race": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "msan": attr.string(
            values = [
                "on",
                "off",
                "auto",
            ],
            default = "auto",
        ),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        "linkmode": attr.string(default=LINKMODE_NORMAL),
    },
    executable = True,
    test = True,
)
"""See go/core.rst#go_test for full documentation."""
