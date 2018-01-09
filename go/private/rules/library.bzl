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

go_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "embed": attr.label_list(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "x_defs": attr.string_dict(),
        "_go_prefix": attr.label(default = go_prefix_default),
        "_go_context_data": attr.label(default = Label("@io_bazel_rules_go//:go_context_data")),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""See go/core.rst#go_library for full documentation."""
