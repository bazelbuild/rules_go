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
    ":context.bzl",
    "go_context",
)
load(
    ":common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
    "pkg_dir",
    "split_srcs",
)
load(
    ":rules/binary.bzl",
    "gc_linkopts",
)
load(
    ":providers.bzl",
    "GoLibrary",
    "INFERRED_PATH",
)
load(
    ":rules/transition.bzl",
    "go_transition_rule",
)
load(
    ":mode.bzl",
    "LINKMODE_NORMAL",
)

def _testmain_library_to_source(go, attr, source, merge):
    source["deps"] = source["deps"] + [attr.library]

def _go_test_impl(ctx):
    """go_test_impl implements go testing.

    It emits an action to run the test generator, and then compiles the
    test into a binary."""

    go = go_context(ctx)

    # Compile the library to test with internal white box tests
    internal_library = go.new_library(go, testfilter = "exclude")
    internal_source = go.library_to_source(go, ctx.attr, internal_library, ctx.coverage_instrumented())
    internal_archive = go.archive(go, internal_source)
    go_srcs = split_srcs(internal_source.srcs).go

    # Compile the library with the external black box tests
    external_library = go.new_library(
        go,
        name = internal_library.name + "_test",
        importpath = internal_library.importpath + "_test",
        testfilter = "only",
    )
    external_source = go.library_to_source(go, struct(
        srcs = [struct(files = go_srcs)],
        deps = internal_archive.direct + [internal_archive],
        x_defs = ctx.attr.x_defs,
    ), external_library, ctx.coverage_instrumented())
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

    main_go = go.declare_file(go, path = "testmain.go")
    arguments = go.builder_args(go, "gentestmain")
    arguments.add("-rundir", run_dir)
    arguments.add("-output", main_go)
    if ctx.configuration.coverage_enabled:
        arguments.add("-coverage")
    arguments.add(
        # the l is the alias for the package under test, the l_test must be the
        # same with the test suffix
        "-import",
        "l=" + internal_source.library.importpath,
    )
    arguments.add(
        "-import",
        "l_test=" + external_source.library.importpath,
    )
    arguments.add("-pkgname", internal_source.library.importpath)
    arguments.add_all(go_srcs, before_each = "-src", format_each = "l=%s")
    ctx.actions.run(
        inputs = go_srcs,
        outputs = [main_go],
        mnemonic = "GoTestGenTest",
        executable = go.toolchain._builder,
        arguments = [arguments],
        env = {
            "RUNDIR": ctx.label.package,
        },
    )

    # Now compile the test binary itself
    test_library = GoLibrary(
        name = go._ctx.label.name + "~testmain",
        label = go._ctx.label,
        importpath = "testmain",
        importmap = "testmain",
        importpath_aliases = (),
        pathtype = INFERRED_PATH,
        is_main = True,
        resolve = None,
    )
    test_deps = external_archive.direct + [external_archive]
    if ctx.configuration.coverage_enabled:
        test_deps.append(go.coverdata)
    test_source = go.library_to_source(go, struct(
        srcs = [struct(files = [main_go] + ctx.files._testmain_additional_srcs)],
        deps = test_deps,
    ), test_library, False)
    test_archive, executable, runfiles = go.binary(
        go,
        name = ctx.label.name,
        source = test_source,
        test_archives = [internal_archive.data],
        gc_linkopts = gc_linkopts(ctx),
        version_file = ctx.version_file,
        info_file = ctx.info_file,
    )

    # Bazel only looks for coverage data if the test target has an
    # InstrumentedFilesProvider. If the provider is found and at least one
    # source file is present, Bazel will set the COVERAGE_OUTPUT_FILE
    # environment variable during tests and will save that file to the build
    # events + test outputs.
    return [
        test_archive,
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles,
            executable = executable,
        ),
        OutputGroupInfo(
            compilation_outputs = [internal_archive.data.file],
        ),
        coverage_common.instrumented_files_info(
            ctx,
            source_attributes = ["srcs"],
            dependency_attributes = ["deps", "embed"],
            extensions = ["go"],
        ),
    ]

_go_test_kwargs = {
    "implementation": _go_test_impl,
    "attrs": {
        "data": attr.label_list(allow_files = True),
        "srcs": attr.label_list(allow_files = go_exts + asm_exts + cgo_exts),
        "deps": attr.label_list(providers = [GoLibrary]),
        "embed": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "rundir": attr.string(),
        "x_defs": attr.string_dict(),
        "linkmode": attr.string(default = LINKMODE_NORMAL),
        "cgo": attr.bool(),
        "cdeps": attr.label_list(),
        "cppopts": attr.string_list(),
        "copts": attr.string_list(),
        "cxxopts": attr.string_list(),
        "clinkopts": attr.string_list(),
        "_go_context_data": attr.label(default = "//:go_context_data"),
        "_testmain_additional_srcs": attr.label_list(
            default = ["@io_bazel_rules_go//go/tools/testwrapper:srcs"],
            allow_files = go_exts,
        ),
        # Workaround for bazelbuild/bazel#6293. See comment in lcov_merger.sh.
        "_lcov_merger": attr.label(
            executable = True,
            default = "@io_bazel_rules_go//go/tools/builders:lcov_merger",
            cfg = "target",
        ),
    },
    "executable": True,
    "test": True,
    "toolchains": ["@io_bazel_rules_go//go:toolchain"],
}

go_test = rule(**_go_test_kwargs)
go_transition_test = go_transition_rule(**_go_test_kwargs)
