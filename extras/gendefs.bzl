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
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "split_srcs",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

def _go_gendefs_impl(ctx):
    go = go_context(ctx)\

    srcs = ctx.files.srcs
    split = split_srcs(srcs)
    
    args = go.builder_args(go)
    args.add_all(split.headers, before_each = "-hdr")

    inputs = (srcs + go.sdk.tools + go.crosstool)
    outputs = []
    for goSrc in split.go:
        out = go.declare_file(go, path = goSrc.dirname, ext = ".gen.go", name = goSrc.basename)
        outputs.append(out)
        args.add("-src", goSrc)
        args.add("-o", out)
    
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoGendefs",
        executable = ctx.executable._gendefs,
        arguments = [args],
        env = go.env,
    )

    library = go.new_library(go)
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    return [
        library,
        source,
        DefaultInfo(
            files = depset(outputs),
        ),
    ]

go_gendefs = go_rule(
    _go_gendefs_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".go", ".h"]),
        "_gendefs": attr.label(
            default = "@io_bazel_rules_go//go/tools/builders:gendefs",
            executable = True,
            cfg = "host",
        )
    }
)
"""See go/extras.rst#go_gendefs for full documentation."""
