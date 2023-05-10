# Copyright 2019 The Bazel Authors. All rights reserved.
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
    "//go/private:mode.bzl",
    "link_mode_args",
)
load("//go/private/actions:utils.bzl", "quote_opts")

def _archive(v):
    importpaths = [v.data.importpath]
    importpaths.extend(v.data.importpath_aliases)
    return "{}={}={}".format(
        ":".join(importpaths),
        v.data.importmap,
        v.data.export_file.path if v.data.export_file else v.data.file.path,
    )

def _embedroot_arg(src):
    return src.root.path

def _embedlookupdir_arg(src):
    root_relative = src.dirname[len(src.root.path):]
    if root_relative.startswith("/"):
        root_relative = root_relative[len("/"):]
    return root_relative

def emit_compilepkg(
        go,
        sources = None,
        cover = None,
        embedsrcs = [],
        importpath = "",
        importmap = "",
        archives = [],
        cgo = False,
        cgo_inputs = depset(),
        cppopts = [],
        copts = [],
        cxxopts = [],
        objcopts = [],
        objcxxopts = [],
        clinkopts = [],
        out_lib = None,
        out_export = None,
        out_cgo_export_h = None,
        gc_goopts = [],
        testfilter = None,  # TODO: remove when test action compiles packages
        recompile_internal_deps = []):
    """Compiles a complete Go package."""
    if sources == None:
        fail("sources is a required parameter")
    if out_lib == None:
        fail("out_lib is a required parameter")

    inputs = (sources + embedsrcs + [go.package_list] +
              [archive.data.export_file for archive in archives] +
              go.sdk.tools + go.sdk.headers + go.stdlib.libs)
    outputs = [out_lib, out_export]
    env = go.env

    args = go.builder_args(go, "compilepkg")
    args.add_all(sources, before_each = "-src")
    args.add_all(embedsrcs, before_each = "-embedsrc", expand_directories = False)
    args.add_all(
        sources + [out_lib] + embedsrcs,
        map_each = _embedroot_arg,
        before_each = "-embedroot",
        uniquify = True,
        expand_directories = False,
    )
    args.add_all(
        sources + [out_lib],
        map_each = _embedlookupdir_arg,
        before_each = "-embedlookupdir",
        uniquify = True,
        expand_directories = False,
    )
    if cover and go.coverdata:
        inputs.append(go.coverdata.data.export_file)
        args.add("-arc", _archive(go.coverdata))
        if go.mode.race:
            args.add("-cover_mode", "atomic")
        else:
            args.add("-cover_mode", "set")
        args.add("-cover_format", go.cover_format)
        args.add_all(cover, before_each = "-cover")
    args.add_all(archives, before_each = "-arc", map_each = _archive)
    if recompile_internal_deps:
        args.add_all(recompile_internal_deps, before_each = "-recompile_internal_deps")
    if importpath:
        args.add("-importpath", importpath)
    else:
        args.add("-importpath", go.label.name)
    if importmap:
        args.add("-p", importmap)
    args.add("-package_list", go.package_list)

    args.add("-o", out_lib)
    args.add("-x", out_export)
    if go.nogo:
        args.add("-nogo", go.nogo)
        inputs.append(go.nogo)
    if out_cgo_export_h:
        args.add("-cgoexport", out_cgo_export_h)
        outputs.append(out_cgo_export_h)
    if testfilter:
        args.add("-testfilter", testfilter)
    args.add_all(go.sdk.experiments, before_each = "-experiment")

    gc_flags = list(gc_goopts)
    gc_flags.extend(go.mode.gc_goopts)
    asm_flags = []
    if go.mode.race:
        gc_flags.append("-race")
    if go.mode.msan:
        gc_flags.append("-msan")
    if go.mode.debug:
        gc_flags.extend(["-N", "-l"])
    gc_flags.extend(go.toolchain.flags.compile)
    gc_flags.extend(link_mode_args(go.mode))
    asm_flags.extend(link_mode_args(go.mode))
    args.add("-gcflags", quote_opts(gc_flags))
    args.add("-asmflags", quote_opts(asm_flags))

    env = go.env
    if cgo:
        inputs.extend(cgo_inputs.to_list())  # OPT: don't expand depset
        inputs.extend(go.crosstool)
        env["CC"] = go.cgo_tools.c_compiler_path
        if cppopts:
            args.add("-cppflags", quote_opts(cppopts))
        if copts:
            args.add("-cflags", quote_opts(copts))
        if cxxopts:
            args.add("-cxxflags", quote_opts(cxxopts))
        if objcopts:
            args.add("-objcflags", quote_opts(objcopts))
        if objcxxopts:
            args.add("-objcxxflags", quote_opts(objcxxopts))
        if clinkopts:
            args.add("-ldflags", quote_opts(clinkopts))

    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoCompilePkg",
        executable = go.toolchain._builder,
        arguments = [args],
        env = go.env,
    )
