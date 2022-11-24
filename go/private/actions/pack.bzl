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
    "//go/private/actions:deprecation.bzl",
    "LEGACY_ACTIONS_DEPRECATION_NOTICE",
)

def emit_pack(
        go,
        in_lib = None,
        out_lib = None,
        objects = [],
        archives = []):
    """See go/toolchains.rst#pack for full documentation."""

    print(LEGACY_ACTIONS_DEPRECATION_NOTICE.format(
        old = "go_context.pack",
        new = "go_context.link",
    ))

    if in_lib == None:
        fail("in_lib is a required parameter")
    if out_lib == None:
        fail("out_lib is a required parameter")

    inputs = [in_lib] + go.sdk.tools + objects + archives

    args = go.builder_args(go, "pack")
    args.add("-in", in_lib)
    args.add("-out", out_lib)
    args.add_all(objects, before_each = "-obj")
    args.add_all(archives, before_each = "-arc")

    go.actions.run(
        inputs = inputs,
        outputs = [out_lib],
        mnemonic = "GoPack",
        executable = go.toolchain._builder,
        arguments = [args],
        env = go.env,
    )
