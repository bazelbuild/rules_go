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
    "@io_bazel_rules_go//go/private:mode.bzl",
    "link_mode_args",
)
load(
    "@io_bazel_rules_go//go/private:skylib/lib/shell.bzl",
    "shell",
)

def _archive(v):
    return "{}={}={}".format(v.data.importpath, v.data.importmap, v.data.file.path)

def emit_compile(
        go,
        sources = None,
        importpath = "",
        archives = [],
        out_lib = None,
        gc_goopts = [],
        testfilter = None,
        asmhdr = None):
    """See go/toolchains.rst#compile for full documentation."""

    if sources == None:
        fail("sources is a required parameter")
    if out_lib == None:
        fail("out_lib is a required parameter")

    if not go.builders.compile:
        if archives:
            fail("compile does not accept deps in bootstrap mode")
        return _bootstrap_compile(go, sources, out_lib, gc_goopts)

    inputs = (sources + [go.package_list] +
              [archive.data.file for archive in archives] +
              go.sdk.tools + go.stdlib.libs)
    outputs = [out_lib]

    builder_args = go.builder_args(go)
    builder_args.add_all(sources, before_each = "-src")
    builder_args.add_all(archives, before_each = "-arc", map_each = _archive)
    builder_args.add("-o", out_lib)
    builder_args.add("-package_list", go.package_list)
    if testfilter:
        builder_args.add("-testfilter", testfilter)

    tool_args = go.tool_args(go)
    if asmhdr:
        tool_args.add("-asmhdr", asmhdr)
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
        tool_args.add("-p", importpath)
    if go.mode.debug:
        tool_args.add_all(["-N", "-l"])
    tool_args.add_all(go.toolchain.flags.compile)
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoCompile",
        executable = go.builders.compile,
        arguments = [builder_args, "--", tool_args],
        env = go.env,
    )

def _bootstrap_compile(go, sources, out_lib, gc_goopts):
    cmd = [shell.quote(go.go.path), "tool", "compile", "-trimpath", "\"$(pwd)\""]
    args = go.actions.args()
    args.add("-o", out_lib)
    args.add_all(gc_goopts)
    args.add_all(sources)
    go.actions.run_shell(
        inputs = sources + go.sdk.libs + go.sdk.tools + [go.go],
        outputs = [out_lib],
        arguments = [args],
        mnemonic = "GoCompile",
        command = "export GOROOT=\"$(pwd)\"/{} && {} \"$@\"".format(shell.quote(go.root), " ".join(cmd)),
        env = {
            "GOROOT_FINAL": "GOROOT",
        },
    )
