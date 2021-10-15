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

"""This is a collection of helper rules. These are not core to building a go binary, but are supplied
to make life a little easier.

gazelle
-------

This rule has moved. See `gazelle rule`_ in the Gazelle repository.

gomock
------

This rule allows you to generate mock interfaces with mockgen (from `golang/mock`_) which can be useful for certain testing scenarios. See  `gomock_rule`_ in the gomock repository.

"""

load(
    "@io_bazel_rules_go//go/private:context.bzl",  #TODO: This ought to be def
    "go_context",
)

_DOC = """``go_embed_data`` generates a .go file that contains data from a file or a
list of files. It should be consumed in the srcs list of one of the
`core go rules`_.

Before using ``go_embed_data``, you must add the following snippet to your
WORKSPACE:

.. code:: bzl

    load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

    go_embed_data_dependencies()


``go_embed_data`` accepts the attributes listed below.
"""

def _go_embed_data_impl(ctx):
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
        "package": attr.string(),
        "var": attr.string(
            default = "Data",
            doc = "Name of the variable that will contain the embedded data.",
        ),
        "src": attr.label(allow_single_file = True),
        "srcs": attr.label_list(allow_files = True),
        "flatten": attr.bool(),
        "unpack": attr.bool(),
        "string": attr.bool(),
        "_embed": attr.label(
            default = "@io_bazel_rules_go//go/tools/builders:embed",
            executable = True,
            cfg = "host",
        ),
        "_go_context_data": attr.label(
            default = "//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
# See go/extras.rst#go_embed_data for full documentation.
