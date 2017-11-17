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
    "GoEmbed",
)
load("@io_bazel_rules_go//go/private:actions/archive.bzl",
    "get_archive",
)

def emit_library(ctx, go_toolchain,
    mode = None,
    importpath = "",
    embed = [],
    want_coverage = False,
    importable = True):
  """See go/toolchains.rst#library for full documentation."""

  srcs = []
  build_srcs = []
  deps = []
  cover_vars = []
  gc_goopts = []
  runfiles = ctx.runfiles()
  cgo_deps = []
  cgo_exports = []
  cgo_archive = None

  for e in embed:
    embed_srcs = getattr(e, "srcs", [])
    srcs.extend(embed_srcs)
    embed_build_srcs = getattr(e, "build_srcs", None)
    if embed_build_srcs:
      build_srcs.extend(embed_build_srcs)
    else:
      build_srcs.extend(embed_srcs)
    deps.extend(getattr(e, "deps", []))
    gc_goopts.extend(getattr(e, "gc_goopts", []))
    cover_vars.extend(getattr(e, "cover_vars", []))
    runfiles = runfiles.merge(getattr(e, "runfiles", None))
    cgo_deps.extend(getattr(e, "cgo_deps", []))
    cgo_exports.extend(getattr(e, "cgo_exports", []))
    embed_cgo_archive = getattr(e, "cgo_archive", None)
    if embed_cgo_archive:
      if cgo_archive:
        fail("multiple libraries with cgo_archive embedded")
      cgo_archive = embed_cgo_archive

  libs = []
  direct = []
  for dep in deps:
    lib = dep[GoLibrary]
    libs.append(lib)
    direct.append(get_archive(dep))
    runfiles = runfiles.merge(lib.runfiles)
    
  source = split_srcs(build_srcs)
  go_srcs = source.go
  if source.c:
    fail("c sources in non cgo rule")
  if not go_srcs:
    fail("no go sources")

  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, sources=go_srcs, mode=mode)
    cover_vars.extend(cvars)

  transformed = structs.to_dict(source)
  transformed["go"] = go_srcs

  build_srcs = join_srcs(struct(**transformed))

  package = GoPackage(
      name = str(ctx.label),
      importpath = importpath, # The import path for this library
      srcs = depset(srcs), # The original sources
  )
  golib = GoLibrary(
      package = package,
      transitive = sets.union([package], *[l.transitive for l in libs]),
      runfiles = runfiles, # The runfiles needed for things including this library
  )
  goembed = GoEmbed(
      srcs = srcs,
      build_srcs = build_srcs,
      deps = deps,
      cover_vars = cover_vars,
      gc_goopts = gc_goopts,
      runfiles = runfiles,
      cgo_deps = cgo_deps,
      cgo_exports = cgo_exports,
      cgo_archive = cgo_archive,
  )
  goarchive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      importpath = importpath,
      goembed = goembed,
      importable = importable,
      direct = [get_archive(dep) for dep in deps],
      runfiles = runfiles,
  )

  return [golib, goembed, goarchive]
