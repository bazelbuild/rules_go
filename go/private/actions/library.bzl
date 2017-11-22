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
    want_coverage = False,
    importable = True):
  """See go/toolchains.rst#library for full documentation."""

  flat = sources.flatten(ctx, source)
  split = split_srcs(flat.build_srcs)
  go_srcs = split.go
  if split.c:
    fail("c sources in non cgo rule in " + str(ctx.label) + " got " + str(split.c))
  if not split.go:
    fail("no go sources in " + str(ctx.label) + " got " + str(flat.build_srcs))
  transformed = structs.to_dict(split)

  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, sources=split.go, mode=mode)
    transformed["go"] = go_srcs
    flat.cover_vars.extend(cvars)


  # This is a temporary hack, cover is about to move
  temp = structs.to_dict(flat)
  temp["build_srcs"] = join_srcs(struct(**transformed))
  flat = GoSource(**temp)
  source = GoSourceList(entries=[flat])

  package = GoPackage(
      name = str(ctx.label),
      importpath = importpath, # The import path for this library
      srcs = depset(flat.srcs), # The original sources
  )
  golib = GoLibrary(
      package = package,
      transitive = sets.union([package], *[dep[GoLibrary].transitive for dep in flat.deps]),
      runfiles = flat.runfiles, # The runfiles needed for things including this library
  )
  goarchive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      importpath = importpath,
      source = source,
      importable = importable,
  )

  return [golib, source, goarchive]
