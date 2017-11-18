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
    "CgoInfo",
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
  direct = []
  cover_vars = []
  dep_runfiles = []
  gc_goopts = []
  cgo_info = None

  for goembed in embed:
    srcs.extend(goembed.srcs)
    direct.extend(goembed.deps)
    gc_goopts.extend(getattr(goembed, "gc_goopts", []))
    embed_cgo_info = getattr(goembed, "cgo_info", None)
    embed_build_srcs = getattr(goembed, "build_srcs", None)
    cover_vars.extend(getattr(goembed, "cover_vars", []))
    if embed_cgo_info:
      if cgo_info:
        fail("multiple libraries with cgo embedded")
      build_srcs.extend(embed_cgo_info.gen_go_srcs)
      cgo_info = embed_cgo_info
    elif embed_build_srcs:
      build_srcs.extend(embed_build_srcs)
    else:
      build_srcs.extend(goembed.srcs)
  
  source = split_srcs(build_srcs)
  go_srcs = source.go
  if source.c:
    fail("c sources in non cgo rule")
  if not go_srcs:
    fail("no go sources")

  if cgo_info:
    dep_runfiles.append(cgo_info.runfiles)

  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, sources=go_srcs, mode=mode)
    cover_vars.extend(cvars)

  transformed = structs.to_dict(source)
  transformed["go"] = go_srcs

  build_srcs = join_srcs(struct(**transformed))

  dylibs = []
  if cgo_info:
    dylibs.extend([d for d in cgo_info.deps if d.path.endswith(".so")])

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  for d in dep_runfiles:
    runfiles = runfiles.merge(d)
  
  package = GoPackage(
      name = str(ctx.label),
      importpath = importpath, # The import path for this library
      srcs = depset(srcs), # The original sources
  )
  golib = GoLibrary(
      package = package,
      transitive = sets.union([package], *[l[GoLibrary].transitive for l in direct]),
      runfiles = runfiles, # The runfiles needed for things including this library
  )
  goembed = GoEmbed(
      srcs = srcs, # The original sources
      build_srcs = build_srcs, # The transformed sources actually compiled
      deps = direct, # The direct depencancies of the library
      cover_vars = cover_vars, # The cover variables for these sources
      cgo_info = cgo_info, # The cgo information for this library or one of its embeds.
      gc_goopts = gc_goopts, # The options this library was compiled with
  )
  goarchive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      importpath = importpath,
      goembed = goembed,
      importable = importable,
      direct = [get_archive(dep) for dep in direct],
      runfiles = runfiles,
  )

  return [golib, goembed, goarchive]
