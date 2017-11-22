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
    "join_srcs",
    "structs",
    "sets",
    "to_set",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoPackage",
    "GoSourceList",
    "GoSource",
    "sources",
)
load("@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "get_archive",
)

def emit_library(ctx, go_toolchain,
    mode = None,
    importpath = "",
    source = None,
    importable = True):
  """See go/toolchains.rst#library for full documentation."""

  transitive = []
  srcs = []
  for s in source.entries:
    srcs.extend(s.srcs)
    transitive.extend([dep[GoLibrary].transitive for dep in s.deps])
  package = GoPackage(
      name = str(ctx.label),
      importpath = importpath, # The import path for this library
      srcs = sets.union(srcs), # The original unfiltered sources
  )
  golib = GoLibrary(
      package = package,
      transitive = sets.union([package], *transitive),
  )
  goarchive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      importpath = importpath,
      source = source,
      importable = importable,
  )

  return [golib, goarchive]
