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
    "//go/private:context.bzl",
    "go_context",
)
load(
    "//go/private:common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
    "pkg_dir",
    "split_srcs",
)
load(
    "//go/private/rules:binary.bzl",
    "gc_linkopts",
)
load(
    "//go/private:providers.bzl",
    "GoArchive",
    "GoLibrary",
    "GoSource",
    "INFERRED_PATH",
    "get_archive",
)
load(
    "//go/private/rules:transition.bzl",
    "go_transition_rule",
)
load(
    "//go/private:mode.bzl",
    "LINKMODE_NORMAL",
)
load(
    "@bazel_skylib//lib:structs.bzl",
    "structs",
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
    external_source, internal_archive = _recompile_external_deps(go, external_source, internal_archive, [t.label for t in ctx.attr.embed])
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
    )

    test_gc_linkopts = gc_linkopts(ctx)
    if not go.mode.debug:
        # Disable symbol table and DWARF generation for test binaries.
        test_gc_linkopts.extend(["-s", "-w"])

    # Link in the run_dir global for testinit
    test_gc_linkopts.extend(["-X", "github.com/bazelbuild/rules_go/go/tools/testinit.RunDir=" + run_dir])

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
    test_deps = external_archive.direct + [external_archive] + ctx.attr._testmain_additional_deps
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
        gc_linkopts = test_gc_linkopts,
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
        "_testmain_additional_deps": attr.label_list(
            providers = [GoLibrary],
            default = ["@io_bazel_rules_go//go/tools/testinit"],
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

def _recompile_external_deps(go, external_source, internal_archive, library_labels):
    """Recompiles some archives in order to split internal and external tests.

    go_test, like 'go test', splits tests into two separate archives: an
    internal archive ('package foo') and an external archive
    ('package foo_test'). The library under test is embedded into the internal
    archive. The external archive may import it and may depend on symbols
    defined in the internal test files.

    To avoid conflicts, the library under test must not be linked into the test
    binary, since the internal test archive embeds the same sources.
    Libraries imported by the external test that transitively import the
    library under test must be recompiled too, or the linker will complain that
    export data they were compiled with doesn't match the export data they
    are linked with.

    This function identifies which archives may need to be recompiled, then
    declares new output files and actions to recompile them. This is an
    unfortunately an expensive process requiring O(V+E) time and space in the
    size of the test's dependency graph for each test.

    Args:
        go: go object returned by go_context.
        external_source: GoSource for the external archive.
        internal_archive: GoArchive for the internal archive.
        library_labels: labels for embedded libraries under test.

    Returns:
        external_soruce: recompiled GoSource for the external archive. If no
            recompilation is needed, the original GoSource is returned.
        internal_archive: recompiled GoArchive for the internal archive. If no
            recompilation is needed, the original GoSource is returned.
    """

    # If no libraries are embedded in the internal archive, then nothing needs
    # to be recompiled.
    if not library_labels:
        return external_source, internal_archive

    # Build a map from labels to GoArchiveData.
    # If none of the librares embedded in the internal archive are in the
    # dependency graph, then nothing needs to be recompiled.
    arc_data_list = depset(transitive = [get_archive(dep).transitive for dep in external_source.deps]).to_list()
    label_to_arc_data = {a.label: a for a in arc_data_list}
    if all([l not in label_to_arc_data for l in library_labels]):
        return external_source, internal_archive

    # Build a depth-first post-order list of dependencies starting with the
    # external archive. Each archive appears after its dependencies and before
    # its dependents.
    #
    # This is tricky because Starlark doesn't support recursion or while loops.
    # We simulate a while loop by iterating over a list of 2N elements where
    # N is the number of archives. Each archive is pushed onto the stack
    # twice: once before its dependencies are pushed, and once after.

    # dep_list is the post-order list of dependencies we're building.
    dep_list = []

    # stack is a stack of targets to process. We're done when it's empty.
    stack = [get_archive(dep).data.label for dep in external_source.deps]

    # deps_pushed tracks the status of each target.
    # DEPS_UNPROCESSED means the target is on the stack, but its dependencies
    # are not.
    # ON_DEP_LIST means the target and its dependencies have been added to
    # dep_list.
    # Non-negative integers are the number of dependencies on the stack that
    # still need to be processed.
    # A target is on the stack if its status is DEPS_UNPROCESSED or 0.
    DEPS_UNPROCESSED = -1
    ON_DEP_LIST = -2
    deps_pushed = {l: DEPS_UNPROCESSED for l in stack}

    # dependents maps labels to lists of known dependents. When a target is
    # processed, its dependents' deps_pushed count is deprecated.
    dependents = {l: [] for l in stack}

    # step is a list to iterate over to simulate a while loop. i tracks
    # iterations.
    step = [None] * (2 * len(arc_data_list))
    i = 0
    for _ in step:
        if len(stack) == 0:
            break
        i += 1

        label = stack.pop()
        if deps_pushed[label] == 0:
            # All deps have been added to dep_list. Append this target to the
            # list. If a dependent is not waiting for anything else, push
            # it back onto the stack.
            dep_list.append(label)
            for p in dependents.get(label, []):
                deps_pushed[p] -= 1
                if deps_pushed[p] == 0:
                    stack.append(p)
            continue

        # deps_pushed[label] == None, indicating we don't know whether this
        # targets dependencies have been processed. Other targets processed
        # earlier may depend on them.
        deps_pushed[label] = 0
        arc_data = label_to_arc_data[label]
        for c in arc_data._dep_labels:
            if c not in deps_pushed:
                # Dependency not seen yet; push it.
                stack.append(c)
                deps_pushed[c] = None
                deps_pushed[label] += 1
                dependents[c] = [label]
            elif deps_pushed[c] != 0:
                # Dependency pushed, not processed; wait for it.
                deps_pushed[label] += 1
                dependents[c].append(label)
        if deps_pushed[label] == 0:
            # No dependencies to wait for; push self.
            stack.append(label)
    if i != len(step):
        fail("assertion failed: iterated %d times instead of %d" % (i, len(step)))

    # Determine which dependencies need to be recompiled because they depend
    # on embedded libraries.
    need_recompile = {}
    for label in dep_list:
        arc_data = label_to_arc_data[label]
        need_recompile[label] = any([
            dep in library_labels or need_recompile[dep]
            for dep in arc_data._dep_labels
        ])

    # Recompile the internal archive without dependencies that need
    # recompilation. This breaks a cycle which occurs because the deps list
    # is shared between the internal and external archive. The internal archive
    # can't import anything that imports itself.
    internal_source = internal_archive.source
    internal_deps = [dep for dep in internal_source.deps if not need_recompile[get_archive(dep).data.label]]
    attrs = structs.to_dict(internal_source)
    attrs["deps"] = internal_deps
    internal_source = GoSource(**attrs)
    internal_archive = go.archive(go, internal_source, _recompile_suffix = ".recompileinternal")

    # Build a map from labels to possibly recompiled GoArchives.
    label_to_archive = {}
    i = 0
    for label in dep_list:
        i += 1
        recompile_suffix = ".recompile%d" % i

        # If this library is the internal archive, use the recompiled version.
        if label == internal_archive.data.label:
            label_to_archive[label] = internal_archive
            continue

        # If this is a library embedded into the internal test archive,
        # use the internal test archive instead.
        if label in library_labels:
            label_to_archive[label] = internal_archive
            continue

        # Create a stub GoLibrary and GoSource from the archive data.
        arc_data = label_to_arc_data[label]
        library = GoLibrary(
            name = arc_data.name,
            label = arc_data.label,
            importpath = arc_data.importpath,
            importmap = arc_data.importmap,
            importpath_aliases = arc_data.importpath_aliases,
            pathtype = arc_data.pathtype,
            resolve = None,
            testfilter = None,
            is_main = False,
        )
        deps = [label_to_archive[d] for d in arc_data._dep_labels]
        source = GoSource(
            library = library,
            mode = go.mode,
            srcs = arc_data.srcs,
            orig_srcs = arc_data.orig_srcs,
            orig_src_map = dict(zip(arc_data.srcs, arc_data._orig_src_map)),
            cover = arc_data._cover,
            x_defs = dict(arc_data._x_defs),
            deps = deps,
            gc_goopts = arc_data._gc_goopts,
            runfiles = go._ctx.runfiles(files = arc_data.data_files),
            cgo = arc_data._cgo,
            cdeps = arc_data._cdeps,
            cppopts = arc_data._cppopts,
            copts = arc_data._copts,
            cxxopts = arc_data._cxxopts,
            clinkopts = arc_data._clinkopts,
            cgo_exports = arc_data._cgo_exports,
        )

        # If this archive needs to be recompiled, use go.archive.
        # Otherwise, create a stub GoArchive, using the original file.
        if need_recompile[label]:
            recompile_suffix = ".recompile%d" % i
            archive = go.archive(go, source, _recompile_suffix = recompile_suffix)
        else:
            archive = GoArchive(
                source = source,
                data = arc_data,
                direct = deps,
                libs = depset(direct = [arc_data.file], transitive = [a.libs for a in deps]),
                transitive = depset(direct = [arc_data], transitive = [a.transitive for a in deps]),
                x_defs = source.x_defs,
                cgo_deps = depset(direct = arc_data._cgo_deps, transitive = [a.cgo_deps for a in deps]),
                cgo_exports = depset(direct = list(source.cgo_exports), transitive = [a.cgo_exports for a in deps]),
                runfiles = source.runfiles,
                mode = go.mode,
            )
        label_to_archive[label] = archive

    # Finally, we need to replace external_source.deps with the recompiled
    # archives.
    attrs = structs.to_dict(external_source)
    attrs["deps"] = [label_to_archive[get_archive(dep).data.label] for dep in external_source.deps]
    return GoSource(**attrs), internal_archive
