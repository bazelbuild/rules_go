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

load(
    "@io_bazel_rules_go//go:def.bzl",
    "go_context",
    "go_library",
)

def _gen_library_impl(ctx):
    go = go_context(ctx)
    src = go.actions.declare_file(ctx.label.name + ".go")
    go.actions.write(src, "package " + ctx.label.name + "\n")
    library = go.new_library(go, srcs = [src])
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    archive = go.archive(go, source)
    return [
        library,
        source,
        archive,
        DefaultInfo(files = depset([archive.data.file])),
    ]

_gen_library = rule(
    _gen_library_impl,
    attrs = {
        "importpath": attr.string(mandatory = True),
        "_go_context_data": attr.label(
            default = "//:go_context_data",
        ),
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "embedsrcs": attr.label_list(
            allow_files = True,
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def _gen_main_src_impl(ctx):
    src = ctx.actions.declare_file(ctx.label.name + ".go")
    lines = [
        "package main",
        "",
        "import (",
    ]
    lines.append("\t_ \"lib\"")
    lines.extend([
        ")",
        "",
        "func main() {}",
    ])
    ctx.actions.write(src, "\n".join(lines))
    return [DefaultInfo(files = depset([src]))]

_gen_main_src = rule(
    _gen_main_src_impl,
)

def generated_embeded(name, srcs, embedsrcs, **kwargs):
    lib_name = "lib"
    _gen_library(
        name = lib_name,
        srcs = srcs,
        importpath = lib_name,
        embedsrcs = embedsrcs,
        visibility = ["//visibility:private"],
    )

    _gen_main_src(
        name = "generated_main_src",
    )

    go_library(
        name = name,
        importpath = "main",
        srcs = [":generated_main_src"],
        deps = [lib_name],
        **kwargs
    )
