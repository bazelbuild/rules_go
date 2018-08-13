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
    "sets",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_C_ARCHIVE",
    "LINKMODE_C_SHARED",
    "LINKMODE_PLUGIN",
)

def emit_asm(
        go,
        source = None,
        hdrs = []):
    """See go/toolchains.rst#asm for full documentation."""

    if source == None:
        fail("source is a required parameter")

    out_obj = go.declare_file(go, path = source.basename[:-2], ext = ".o")
    inputs = hdrs + go.sdk.tools + go.sdk.headers + go.stdlib.libs + [source]

    args = go.builder_args(go)
    args.add_all([source, "--"])
    includes = ([go.sdk.root_file.dirname + "/pkg/include"] +
                [f.dirname for f in hdrs])

    # TODO(#1463): use uniquify=True when available.
    includes = sorted({i: None for i in includes}.keys())
    args.add_all(includes, before_each = "-I")
    args.add_all(["-trimpath", ".", "-o", out_obj])
    if go.mode.link in [LINKMODE_C_ARCHIVE, LINKMODE_C_SHARED]:
        args.add("-shared")
    if go.mode.link == LINKMODE_PLUGIN:
        args.add("-dynlink")
    go.actions.run(
        inputs = inputs,
        outputs = [out_obj],
        mnemonic = "GoAsm",
        executable = go.builders.asm,
        arguments = [args],
        env = go.env,
    )
    return out_obj
