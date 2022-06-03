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
    "//go/private:mode.bzl",
    "link_mode_args",
)
load(
    "//go/private/actions:deprecation.bzl",
    "LEGACY_ACTIONS_DEPRECATION_NOTICE",
)

def _archive(v):
    importpaths = [v.data.importpath]
    importpaths.extend(v.data.importpath_aliases)
    return "{}={}={}".format(
        ":".join(importpaths),
        v.data.importmap,
        v.data.export_file.path if v.data.export_file else v.data.file.path,
    )

def emit_compile(
        go,
        sources = None,
        importpath = "",  # actually importmap, left as importpath for compatibility
        archives = [],
        out_lib = None,
        out_export = None,
        gc_goopts = [],
        testfilter = None,
        asmhdr = None):
    """See go/toolchains.rst#compile for full documentation."""

    print(LEGACY_ACTIONS_DEPRECATION_NOTICE.format(
        old = "go_context.compile",
        new = "go_context.archive",
    ))

    if sources == None:
        fail("sources is a required parameter")
    if out_lib == None:
        fail("out_lib is a required parameter")

    inputs = (sources + [go.package_list] +
              [archive.data.export_file for archive in archives] +
              go.sdk.tools + go.sdk.headers + go.stdlib.libs)
    outputs = [out_lib, out_export]

    builder_args = go.builder_args(go, "compile")
    builder_args.add_all(sources, before_each = "-src")
    builder_args.add_all(archives, before_each = "-arc", map_each = _archive)
    builder_args.add("-o", out_lib)
    builder_args.add("-x", out_export)
    builder_args.add("-package_list", go.package_list)
    if testfilter:
        builder_args.add("-testfilter", testfilter)
    if go.nogo:
        builder_args.add("-nogo", go.nogo)
        inputs.append(go.nogo)

    tool_args = go.tool_args(go)
    if asmhdr:
        builder_args.add("-asmhdr", asmhdr)
        outputs.append(asmhdr)
    tool_args.add("-trimpath", ".")

    #TODO: Check if we really need this expand make variables in here
    #TODO: If we really do then it needs to be moved all the way back out to the rule
    gc_goopts = [go._ctx.expand_make_variables("gc_goopts", f, {}) for f in gc_goopts]
    tool_args.add_all(gc_goopts)
    if go.mode.race:
        tool_args.add("-race")
    if go.mode.msan:
        tool_args.add("-msan")
    tool_args.add_all(link_mode_args(go.mode))
    if importpath:
        builder_args.add("-p", importpath)
    if go.mode.debug:
        tool_args.add_all(["-N", "-l"])
    tool_args.add_all(go.toolchain.flags.compile)
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoCompile",
        executable = go.toolchain._builder,
        arguments = [builder_args, "--", tool_args],
        env = go.env,
    )
