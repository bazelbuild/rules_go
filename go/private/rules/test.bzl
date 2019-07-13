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
    "@io_bazel_rules_go_compat//:compat.bzl",
    "providers_with_coverage",
)
load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
    "pkg_dir",
    "split_srcs",
)
load(
    "@io_bazel_rules_go//go/private:rules/binary.bzl",
    "gc_linkopts",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "INFERRED_PATH",
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
    "@io_bazel_rules_go//go/platform:list.bzl",
    "GOARCH",
    "GOOS",
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

    main_go = go.declare_file(go, "testmain.go")
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
        srcs = [struct(files = [main_go])],
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
    # InstrumentedFilesProvider. The coverage_common module can create
    # this provider, but it was introduced in v23, and we can't use
    # the legacy syntax anymore. We use the compatibility layer to
    # support old versions of Bazel.
    #
    # If the provider is found and at least one source file is present, Bazel
    # will set the COVERAGE_OUTPUT_FILE environment variable during tests
    # and will save that file to the build events + test outputs.
    return providers_with_coverage(
        ctx,
        extensions = ["go"],
        source_attributes = ["srcs"],
        dependency_attributes = ["deps", "embed"],
        providers = [
            test_archive,
            DefaultInfo(
                files = depset([executable]),
                runfiles = runfiles,
                executable = executable,
            ),
            OutputGroupInfo(
                compilation_outputs = [internal_archive.data.file],
            ),
        ],
    )

go_test = go_rule(
    _go_test_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "srcs": attr.label_list(allow_files = go_exts + asm_exts + cgo_exts),
        "deps": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "embed": attr.label_list(
            providers = [GoLibrary],
            aspects = [go_archive_aspect],
        ),
        "importpath": attr.string(),
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
        "goos": attr.string(
            values = GOOS.keys() + ["auto"],
            default = "auto",
        ),
        "goarch": attr.string(
            values = GOARCH.keys() + ["auto"],
            default = "auto",
        ),
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
        # Workaround for bazelbuild/bazel#6293. See comment in lcov_merger.sh.
        "_lcov_merger": attr.label(
            executable = True,
            default = "@io_bazel_rules_go//go/tools/builders:lcov_merger",
            cfg = "target",
        ),
    },
    executable = True,
    test = True,
)
"""See go/core.rst#go_test for full documentation."""
