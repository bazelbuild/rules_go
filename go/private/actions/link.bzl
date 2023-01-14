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
    "//go/private:common.bzl",
    "as_set",
    "count_group_matches",
    "has_shared_lib_extension",
)
load(
    "//go/private:mode.bzl",
    "LINKMODE_NORMAL",
    "LINKMODE_PLUGIN",
    "extld_from_cc_toolchain",
    "extldflags_from_cc_toolchain",
)
load(
    "//go/private:rpath.bzl",
    "rpath",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)

def _format_archive(d):
    return "{}={}={}".format(d.label, d.importmap, d.file.path)

def _transitive_archives_without_test_archives(archive, test_archives):
    # Build the set of transitive dependencies. Currently, we tolerate multiple
    # archives with the same importmap (though this will be an error in the
    # future), but there is a special case which is difficult to avoid:
    # If a go_test has internal and external archives, and the external test
    # transitively depends on the library under test, we need to exclude the
    # library under test and use the internal test archive instead.
    deps = depset(transitive = [d.transitive for d in archive.direct])
    result = {}

    # Unfortunately, Starlark doesn't support set()
    test_imports = {}
    for t in test_archives:
        test_imports[t.importmap] = True
    for d in deps.to_list():
        if d.importmap in test_imports:
            continue
        if d.importmap in result:
            print("Multiple copies of {} passed to the linker. Ignoring {} in favor of {}".format(d.importmap, d.file.path, result[d.importmap].file.path))
            continue
        result[d.importmap] = d
    return result.values()

def emit_link(
        go,
        archive = None,
        test_archives = [],
        executable = None,
        gc_linkopts = [],
        version_file = None,
        info_file = None):
    """See go/toolchains.rst#link for full documentation."""

    if archive == None:
        fail("archive is a required parameter")
    if executable == None:
        fail("executable is a required parameter")

    # Exclude -lstdc++ from link options. We don't want to link against it
    # unless we actually have some C++ code. _cgo_codegen will include it
    # in archives via CGO_LDFLAGS if it's needed.
    extldflags = [f for f in extldflags_from_cc_toolchain(go) if f not in ("-lstdc++", "-lc++")]

    if go.coverage_enabled:
        extldflags.append("--coverage")
    gc_linkopts = list(gc_linkopts)
    gc_linkopts.extend(go.mode.gc_linkopts)
    gc_linkopts, extldflags = _extract_extldflags(gc_linkopts, extldflags)
    builder_args = go.builder_args(go, "link")
    tool_args = go.tool_args(go)

    # Add in any mode specific behaviours
    if go.mode.race:
        tool_args.add("-race")
    if go.mode.msan:
        tool_args.add("-msan")

    if go.mode.pure:
        tool_args.add("-linkmode", "internal")
    else:
        extld = extld_from_cc_toolchain(go)
        tool_args.add_all(extld)
        if extld and (go.mode.static or
                      go.mode.race or
                      go.mode.link != LINKMODE_NORMAL or
                      go.mode.goos == "windows" and go.mode.msan):
            # Force external linking for the following conditions:
            # * Mode is static but not pure: -static must be passed to the C
            #   linker if the binary contains cgo code. See #2168, #2216.
            # * Non-normal build mode: may not be strictly necessary, especially
            #   for modes like "pie".
            # * Race or msan build for Windows: Go linker has pairwise
            #   incompatibilities with mingw, and we get link errors in race mode.
            #   Using the C linker avoids that. Race and msan always require a
            #   a C toolchain. See #2614.
            # * Linux race builds: we get linker errors during build with Go's
            #   internal linker. For example, when using zig cc v0.10
            #   (clang-15.0.3):
            #
            #       runtime/cgo(.text): relocation target memset not defined
            tool_args.add("-linkmode", "external")

    if go.mode.static:
        extldflags.append("-static")
    if go.mode.link != LINKMODE_NORMAL:
        builder_args.add("-buildmode", go.mode.link)
    if go.mode.link == LINKMODE_PLUGIN:
        tool_args.add("-pluginpath", archive.data.importpath)

    arcs = _transitive_archives_without_test_archives(archive, test_archives)
    arcs.extend(test_archives)
    if (go.coverage_enabled and go.coverdata and
        not any([arc.importmap == go.coverdata.data.importmap for arc in arcs])):
        arcs.append(go.coverdata.data)
    builder_args.add_all(arcs, before_each = "-arc", map_each = _format_archive)
    builder_args.add("-package_list", go.package_list)

    # Build a list of rpaths for dynamic libraries we need to find.
    # rpaths are relative paths from the binary to directories where libraries
    # are stored. Binaries that require these will only work when installed in
    # the bazel execroot. Most binaries are only dynamically linked against
    # system libraries though.
    cgo_rpaths = sorted(collections.uniq([
        f
        for d in archive.cgo_deps.to_list()
        if has_shared_lib_extension(d.basename)
        for f in rpath.flags(go, d, executable = executable)
    ]))
    extldflags.extend(cgo_rpaths)

    # Process x_defs, and record whether stamping is used.
    stamp_x_defs_volatile = False
    stamp_x_defs_stable = False
    for k, v in archive.x_defs.items():
        builder_args.add("-X", "%s=%s" % (k, v))
        if go.stamp:
            stable_vars_count = (count_group_matches(v, "{STABLE_", "}") +
                                 v.count("{BUILD_EMBED_LABEL}") +
                                 v.count("{BUILD_USER}") +
                                 v.count("{BUILD_HOST}"))
            if stable_vars_count > 0:
                stamp_x_defs_stable = True
            if count_group_matches(v, "{", "}") != stable_vars_count:
                stamp_x_defs_volatile = True

    # Stamping support
    stamp_inputs = []
    if stamp_x_defs_stable:
        stamp_inputs.append(info_file)
    if stamp_x_defs_volatile:
        stamp_inputs.append(version_file)
    if stamp_inputs:
        builder_args.add_all(stamp_inputs, before_each = "-stamp")

    builder_args.add("-o", executable)
    builder_args.add("-main", archive.data.file)
    builder_args.add("-p", archive.data.importmap)
    tool_args.add_all(gc_linkopts)
    tool_args.add_all(go.toolchain.flags.link)
    builder_args.add_all(go.sdk.experiments, before_each = "-experiment")

    # Do not remove, somehow this is needed when building for darwin/arm only.
    tool_args.add("-buildid=redacted")
    if go.mode.strip:
        tool_args.add("-w")
    tool_args.add_joined("-extldflags", extldflags, join_with = " ")

    conflict_err = _check_conflicts(arcs)
    if conflict_err:
        # Report package conflict errors in execution instead of analysis.
        # We could call fail() with this message, but Bazel prints a stack
        # that doesn't give useful information.
        builder_args.add("-conflict_err", conflict_err)

    inputs_direct = stamp_inputs + [go.sdk.package_list]
    if go.coverage_enabled and go.coverdata:
        inputs_direct.append(go.coverdata.data.file)
    inputs_transitive = [
        archive.libs,
        archive.cgo_deps,
        as_set(go.crosstool),
        as_set(go.sdk.tools),
        as_set(go.stdlib.libs),
    ]
    inputs = depset(direct = inputs_direct, transitive = inputs_transitive)

    go.actions.run(
        inputs = inputs,
        outputs = [executable],
        mnemonic = "GoLink",
        executable = go.toolchain._builder,
        arguments = [builder_args, "--", tool_args],
        env = go.env,
    )

def _extract_extldflags(gc_linkopts, extldflags):
    """Extracts -extldflags from gc_linkopts and combines them into a single list.

    Args:
      gc_linkopts: a list of flags passed in through the gc_linkopts attributes.
        ctx.expand_make_variables should have already been applied. -extldflags
        may appear multiple times in this list.
      extldflags: a list of flags to be passed to the external linker.

    Return:
      A tuple containing the filtered gc_linkopts with external flags removed,
      and a combined list of external flags. Each string in the returned
      extldflags list may contain multiple flags, separated by whitespace.
    """
    filtered_gc_linkopts = []
    is_extldflags = False
    for opt in gc_linkopts:
        if is_extldflags:
            is_extldflags = False
            extldflags.append(opt)
        elif opt == "-extldflags":
            is_extldflags = True
        else:
            filtered_gc_linkopts.append(opt)
    return filtered_gc_linkopts, extldflags

def _check_conflicts(arcs):
    importmap_to_label = {}
    for arc in arcs:
        if arc.importmap in importmap_to_label:
            return """package conflict error: {}: multiple copies of package passed to linker:
	{}
	{}
Set "importmap" to different paths or use 'bazel cquery' to ensure only one
package with this path is linked.""".format(
                arc.importmap,
                importmap_to_label[arc.importmap],
                arc.label,
            )
        importmap_to_label[arc.importmap] = arc.label
    for arc in arcs:
        for dep_importmap, dep_label in zip(arc._dep_importmaps, arc._dep_labels):
            if dep_importmap not in importmap_to_label:
                return "package conflict error: {}: package needed by {} was not passed to linker".format(
                    dep_importmap,
                    arc.label,
                )
            if importmap_to_label[dep_importmap] != dep_label:
                err = """package conflict error: {}: package imports {}
	  was compiled with: {}
	but was linked with: {}""".format(
                    arc.importmap,
                    dep_importmap,
                    dep_label,
                    importmap_to_label[dep_importmap],
                )
                if importmap_to_label[dep_importmap].name.endswith("_test"):
                    err += """
This sometimes happens when an external test (package ending with _test)
imports a package that imports the library being tested. This is not supported."""
                err += "\nSee https://github.com/bazelbuild/rules_go/issues/1877."
                return err
    return None
