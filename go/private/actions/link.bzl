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
    "@io_bazel_rules_go//go/private:common.bzl",
    "as_set",
    "has_shared_lib_extension",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_NORMAL",
    "LINKMODE_PLUGIN",
    "extld_from_cc_toolchain",
    "extldflags_from_cc_toolchain",
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
    return [d for d in deps.to_list() if not any([d.importmap == t.importmap for t in test_archives])]

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

    #TODO: There has to be a better way to work out the rpath
    config_strip = len(go._ctx.configuration.bin_dir.path) + 1
    pkg_depth = executable.dirname[config_strip:].count("/") + 1

    # Exclude -lstdc++ from link options. We don't want to link against it
    # unless we actually have some C++ code. _cgo_codegen will include it
    # in archives via CGO_LDFLAGS if it's needed.
    extldflags = [f for f in extldflags_from_cc_toolchain(go) if f not in ("-lstdc++", "-lc++")]

    if go.coverage_enabled:
        extldflags.append("--coverage")
    gc_linkopts, extldflags = _extract_extldflags(gc_linkopts, extldflags)
    builder_args = go.builder_args(go, "link")
    tool_args = go.tool_args(go)

    # Add in any mode specific behaviours
    tool_args.add_all(extld_from_cc_toolchain(go))
    if go.mode.race:
        tool_args.add("-race")
    if go.mode.msan:
        tool_args.add("-msan")
    if (go.mode.static and not go.mode.pure) or go.mode.link != LINKMODE_NORMAL:
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
    # TODO: there has to be a better way to work out the rpath.
    config_strip = len(go._ctx.configuration.bin_dir.path) + 1
    pkg_depth = executable.dirname[config_strip:].count("/") + 1
    origin = "@loader_path/" if go.mode.goos == "darwin" else "$ORIGIN/"
    base_rpath = origin + "../" * pkg_depth
    cgo_dynamic_deps = [
        d
        for d in archive.cgo_deps.to_list()
        if has_shared_lib_extension(d.basename)
    ]
    cgo_rpaths = []
    for d in cgo_dynamic_deps:
        short_dir = d.dirname[len(d.root.path) + len("/"):]
        cgo_rpaths.append("-Wl,-rpath,{}/{}".format(base_rpath, short_dir))
    cgo_rpaths = sorted({p: None for p in cgo_rpaths}.keys())
    extldflags.extend(cgo_rpaths)

    # Process x_defs, either adding them directly to linker options, or
    # saving them to process through stamping support.
    stamp_x_defs = False
    for k, v in archive.x_defs.items():
        if go.stamp and v.startswith("{") and v.endswith("}"):
            builder_args.add("-Xstamp", "%s=%s" % (k, v[1:-1]))
            stamp_x_defs = True
        else:
            builder_args.add("-X", "%s=%s" % (k, v))

    # Stamping support
    stamp_inputs = []
    if stamp_x_defs:
        stamp_inputs = [info_file, version_file]
        builder_args.add_all(stamp_inputs, before_each = "-stamp")

    builder_args.add("-o", executable)
    builder_args.add("-main", archive.data.file)
    builder_args.add("-p", archive.data.importmap)
    tool_args.add_all(gc_linkopts)
    tool_args.add_all(go.toolchain.flags.link)

    # Do not remove, somehow this is needed when building for darwin/arm only.
    tool_args.add("-buildid=redacted")
    if go.mode.strip:
        tool_args.add("-w")
    tool_args.add_joined("-extldflags", extldflags, join_with = " ")

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
