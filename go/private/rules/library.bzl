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
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
)
load(
    "@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix_default",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

def _go_library_impl(ctx):
  """Implements the go_library() rule."""
  go = go_context(ctx)
  library = go.new_library(go)
  source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
  archive = go.archive(go, source)

  return [
      library, source, archive,
      DefaultInfo(
          files = depset([archive.data.file]),
      ),
      OutputGroupInfo(
          cgo_exports = archive.cgo_exports,
      ),
  ]

go_library = go_rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "_go_prefix": attr.label(default = go_prefix_default),
    },
)
"""See go/core.rst#go_library for full documentation."""

go_tool_library = go_rule(
    _go_library_impl,
    bootstrap_attrs = [
        "_builders",
        "_stdlib",
    ],
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "importmap": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "_go_prefix": attr.label(default = go_prefix_default),
    },
)
"""
This is used instead of `go_library` for packages that are depended on
implicitly by code generated within the Go rules. This avoids a
bootstrapping problem.
"""
