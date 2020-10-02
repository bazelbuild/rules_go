# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""bindata.bzl provides the bindata rule for embedding data in .go files"""

load(
    "@io_bazel_rules_go//go:def.bzl",
    "go_context",
)

def _bindata_impl(ctx):
    go = go_context(ctx)
    out = go.declare_file(go, ext = ".go")
    arguments = ctx.actions.args()
    arguments.add_all([
        "-o",
        out,
        "-pkg",
        ctx.attr.package,
        "-prefix",
        ctx.label.package,
    ])
    if not ctx.attr.compress:
        arguments.add("-nocompress")
    if not ctx.attr.metadata:
        arguments.add("-nometadata")
    if not ctx.attr.memcopy:
        arguments.add("-nomemcopy")
    if not ctx.attr.modtime:
        arguments.add_all(["-modtime", "0"])
    if ctx.attr.extra_args:
        arguments.add_all(ctx.attr.extra_args)
    srcs = [f.path for f in ctx.files.srcs]
    if ctx.attr.strip_external and any([f.startswith("external/") for f in srcs]):
        arguments.add("-prefix", ctx.label.workspace_root + "/" + ctx.label.package)
    arguments.add_all(srcs)
    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [out],
        mnemonic = "GoBindata",
        executable = ctx.executable._bindata,
        arguments = [arguments],
    )
    return [
        DefaultInfo(
            files = depset([out]),
        ),
    ]

bindata = rule(
    implementation = _bindata_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "package": attr.string(mandatory = True),
        "compress": attr.bool(default = True),
        "metadata": attr.bool(default = False),
        "memcopy": attr.bool(default = True),
        "modtime": attr.bool(default = False),
        "strip_external": attr.bool(default = False),
        "extra_args": attr.string_list(),
        "_bindata": attr.label(
            executable = True,
            cfg = "host",
            default = "@com_github_kevinburke_go_bindata//go-bindata:go-bindata",
        ),
        "_go_context_data": attr.label(
            default = "//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
