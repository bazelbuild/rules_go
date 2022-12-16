# Copyright 2017 The Bazel Authors. All rights reserved.
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
    "//go/private:context.bzl",  #TODO: This ought to be def
    "go_context",
)
load(
    "//go/private:go_toolchain.bzl",
    "GO_TOOLCHAIN",
)

_DOC = """**Deprecated**: Will be removed in rules_go 0.39.

`go_embed_data` generates a .go file that contains data from a file or a
list of files. It should be consumed in the srcs list of one of the
[core go rules].

Before using `go_embed_data`, you must add the following snippet to your
WORKSPACE:

``` bzl
load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

go_embed_data_dependencies()
```

`go_embed_data` accepts the attributes listed below.
"""

def _go_embed_data_impl(ctx):
    print("Embedding is now better handled by using rules_go's built-in embedding functionality (https://github.com/bazelbuild/rules_go/blob/master/docs/go/core/rules.md#go_library-embedsrcs). The `go_embed_data` rule is deprecated and will be removed in rules_go version 0.39.")

    go = go_context(ctx)
    if ctx.attr.src and ctx.attr.srcs:
        fail("%s: src and srcs attributes cannot both be specified" % ctx.label)
    if ctx.attr.src and ctx.attr.flatten:
        fail("%s: src and flatten attributes cannot both be specified" % ctx.label)

    args = ctx.actions.args()
    if ctx.attr.src:
        srcs = [ctx.file.src]
    else:
        srcs = ctx.files.srcs
        args.add("-multi")

    if ctx.attr.package:
        package = ctx.attr.package
    else:
        _, _, package = ctx.label.package.rpartition("/")
        if package == "":
            fail("%s: must provide package attribute for go_embed_data rules in the repository root directory" % ctx.label)

    out = go.declare_file(go, ext = ".go")
    args.add_all([
        "-workspace",
        ctx.workspace_name,
        "-label",
        str(ctx.label),
        "-out",
        out,
        "-package",
        package,
        "-var",
        ctx.attr.var,
    ])
    if ctx.attr.flatten:
        args.add("-flatten")
    if ctx.attr.string:
        args.add("-string")
    if ctx.attr.unpack:
        args.add("-unpack")
        args.add("-multi")
    args.add_all(srcs)

    library = go.new_library(go, srcs = [out])
    source = go.library_to_source(go, {}, library, ctx.coverage_instrumented())

    ctx.actions.run(
        outputs = [out],
        inputs = srcs,
        executable = ctx.executable._embed,
        arguments = [args],
        mnemonic = "GoSourcesData",
    )
    return [
        DefaultInfo(files = depset([out])),
        library,
        source,
    ]

go_embed_data = rule(
    implementation = _go_embed_data_impl,
    doc = _DOC,
    attrs = {
        "package": attr.string(
            doc = "Go package name for the generated .go file.",
        ),
        "var": attr.string(
            default = "Data",
            doc = "Name of the variable that will contain the embedded data.",
        ),
        "src": attr.label(
            allow_single_file = True,
            doc = """A single file to embed. This cannot be used at the same time as `srcs`.
            The generated file will have a variable of type `[]byte` or `string` with the contents of this file.""",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = """A list of files to embed. This cannot be used at the same time as `src`.
            The generated file will have a variable of type `map[string][]byte` or `map[string]string` with the contents
            of each file. The map keys are relative paths of the files from the repository root. Keys for files in external
            repositories will be prefixed with `"external/repo/"` where "repo" is the name of the external repository.""",
        ),
        "flatten": attr.bool(
            doc = "If `True` and `srcs` is used, map keys are file base names instead of relative paths.",
        ),
        "unpack": attr.bool(
            doc = "If `True`, sources are treated as archives and their contents will be stored. Supported formats are `.zip` and `.tar`",
        ),
        "string": attr.bool(
            doc = "If `True`, the embedded data will be stored as `string` instead of `[]byte`.",
        ),
        "_embed": attr.label(
            default = "//go/tools/builders:embed",
            executable = True,
            cfg = "exec",
        ),
        "_go_context_data": attr.label(
            default = "//:go_context_data",
        ),
    },
    toolchains = [GO_TOOLCHAIN],
)
# See /docs/go/extras/extras.md#go_embed_data for full documentation.
