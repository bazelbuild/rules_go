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

load("@io_bazel_rules_go//go/private:common.bzl",
    "split_srcs",
    "to_set",
    "sets",
)
load("@io_bazel_rules_go//go/private:rules/helpers.bzl",
    "library_to_source",
    "new_aspect_provider",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "mode_string",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoArchive",
    "GoArchiveData",
    "GoSource",
)
load("@io_bazel_rules_go//go/platform:list.bzl",
    "GOOS",
    "GOARCH",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
)


def _go_archive_aspect_impl(target, ctx):
  mode = get_mode(ctx, ctx.rule.attr._go_toolchain_flags)
  source = target[GoSource] if GoSource in target else None
  archive = target[GoArchive] if GoArchive in target else None
  if source and source.mode == mode:
    # The base layer already built the right mode for us
    return [new_aspect_provider(
      source = source,
      archive = archive,
    )]
  if not GoLibrary in target:
    # Not a rule we can do anything with
    return []
  # We have a library and we need to compile it in a new mode
  library = target[GoLibrary]
  source = library_to_source(ctx, ctx.rule.attr, library, mode)
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  archive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      source = source,
  )
  return [new_aspect_provider(
    source = source,
    archive = archive,
  )]

go_archive_aspect = aspect(
    _go_archive_aspect_impl,
    attr_aspects = ["deps", "embed", "compiler"],
    attrs = {
        "pure": attr.string(values=["on", "off", "auto"]),
        "static": attr.string(values=["on", "off", "auto"]),
        "msan": attr.string(values=["on", "off", "auto"]),
        "race": attr.string(values=["on", "off", "auto"]),
        "goos": attr.string(values=GOOS.keys() + ["auto"], default="auto"),
        "goarch": attr.string(values=GOARCH.keys() + ["auto"], default="auto"),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
