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

"""
# Core Go rules

.. _"Make variable": https://docs.bazel.build/versions/master/be/make-variables.html
.. _Bourne shell tokenization: https://docs.bazel.build/versions/master/be/common-definitions.html#sh-tokenization
.. _Gazelle: https://github.com/bazelbuild/bazel-gazelle
.. _GoArchive: providers.rst#GoArchive
.. _GoLibrary: providers.rst#GoLibrary
.. _GoPath: providers.rst#GoPath
.. _GoSource: providers.rst#GoSource
.. _build constraints: https://golang.org/pkg/go/build/#hdr-Build_Constraints
.. _cc_library deps: https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library.deps
.. _cgo: http://golang.org/cmd/cgo/
.. _config_setting: https://docs.bazel.build/versions/master/be/general.html#config_setting
.. _data dependencies: https://docs.bazel.build/versions/master/build-ref.html#data
.. _goarch: modes.rst#goarch
.. _goos: modes.rst#goos
.. _mode attributes: modes.rst#mode-attributes
.. _nogo: nogo.rst#nogo
.. _pure: modes.rst#pure
.. _race: modes.rst#race
.. _msan: modes.rst#msan
.. _select: https://docs.bazel.build/versions/master/be/functions.html#select
.. _shard_count: https://docs.bazel.build/versions/master/be/common-definitions.html#test.shard_count
.. _static: modes.rst#static
.. _test_arg: https://docs.bazel.build/versions/master/user-manual.html#flag--test_arg
.. _test_filter: https://docs.bazel.build/versions/master/user-manual.html#flag--test_filter
.. _test_env: https://docs.bazel.build/versions/master/user-manual.html#flag--test_env
.. _write a CROSSTOOL file: https://github.com/bazelbuild/bazel/wiki/Yet-Another-CROSSTOOL-Writing-Tutorial
.. _bazel: https://pkg.go.dev/github.com/bazelbuild/rules_go/go/tools/bazel?tab=doc

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

These are the core go rules, required for basic operation.
The intent is that these rules are sufficient to match the capabilities of the normal go tools.

.. contents:: :depth: 2

"""

load(
    "//go/private:common.bzl",
    "asm_exts",
    "cgo_exts",
    "go_exts",
)
load(
    "//go/private:context.bzl",
    "go_context",
)
load(
    "//go/private:providers.bzl",
    "GoLibrary",
    "INFERRED_PATH",
)

def _go_library_impl(ctx):
    """Implements the go_library() rule."""
    go = go_context(ctx)
    if go.pathtype == INFERRED_PATH:
        fail("importpath must be specified in this library or one of its embedded libraries")
    library = go.new_library(go)
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    archive = go.archive(go, source)

    return [
        library,
        source,
        archive,
        DefaultInfo(
            files = depset([archive.data.file]),
        ),
        OutputGroupInfo(
            cgo_exports = archive.cgo_exports,
            compilation_outputs = [archive.data.file],
        ),
    ]

go_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "srcs": attr.label_list(allow_files = go_exts + asm_exts + cgo_exts),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "importpath_aliases": attr.string_list(),  # experimental, undocumented
        "embed": attr.label_list(providers = [GoLibrary]),
        "embedsrcs": attr.label_list(allow_files = True),
        "gc_goopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "cgo": attr.bool(),
        "cdeps": attr.label_list(),
        "cppopts": attr.string_list(),
        "copts": attr.string_list(),
        "cxxopts": attr.string_list(),
        "clinkopts": attr.string_list(),
        "_go_context_data": attr.label(default = "//:go_context_data"),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
# See go/core.rst#go_library for full documentation.

go_tool_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "_go_config": attr.label(default = "//:go_config"),
        "_cgo_context_data": attr.label(default = "//:cgo_context_data_proxy"),
        "_stdlib": attr.label(default = "//:stdlib"),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
# This is used instead of `go_library` for dependencies of the `nogo` rule and
# packages that are depended on implicitly by code generated within the Go rules.
# This avoids a bootstrapping problem.

# See go/core.rst#go_tool_library for full documentation.
