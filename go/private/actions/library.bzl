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
    "dict_of",
    "split_srcs",
    "join_srcs",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "CgoInfo",
    "GoLibrary",
    "GoEmbed",
)
load("@io_bazel_rules_go//go/private:actions/archive.bzl",
    "get_archive",
)

def emit_library(ctx, go_toolchain,
    mode = None,
    importpath = "",
    srcs = (),
    deps = (),
    cgo_info = None,
    embed = (),
    want_coverage = False,
    importable = True):
  """See go/toolchains.rst#library for full documentation."""
  dep_runfiles = [d.data_runfiles for d in deps]
  direct = depset()
  direct_archives = depset()
  gc_goopts = tuple(ctx.attr.gc_goopts)
  cover_vars = ()
  if cgo_info:
    build_srcs = cgo_info.gen_go_srcs
    cgo_info_label = ctx.label
  else:
    build_srcs = srcs
    cgo_info_label = None
  for t in embed:
    goembed = t[GoEmbed]
    direct_archives += get_archive(t).direct
    srcs = goembed.srcs + srcs
    build_srcs = goembed.build_srcs + build_srcs
    cover_vars += goembed.cover_vars
    direct += goembed.deps
    dep_runfiles += [t.data_runfiles]
    gc_goopts += getattr(goembed, "gc_goopts", ())
    embed_cgo_info = getattr(goembed, "cgo_info", None)
    if embed_cgo_info:
      if cgo_info:
        fail("at most one embedded library may have cgo, but " +
             "both %s and %s have cgo" % (cgo_info_label, t.label))
      cgo_info = embed_cgo_info
      cgo_info_label = t.label

  source = split_srcs(build_srcs)
  go_srcs = source.go
  if source.c:
    fail("c sources in non cgo rule")
  if not go_srcs:
    fail("no go sources")

  if cgo_info:
    dep_runfiles += [cgo_info.runfiles]

  for dep in deps:
    direct += [dep[GoLibrary]]
    direct_archives += [get_archive(dep)]

  transitive = depset()
  for golib in direct:
    transitive += [golib]
    transitive += golib.transitive

  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, sources=go_srcs, mode=mode)
    cover_vars += cvars

  transformed = dict_of(source)
  transformed["go"] = go_srcs

  build_srcs = join_srcs(struct(**transformed))

  dylibs = []
  if cgo_info:
    dylibs += [d for d in cgo_info.deps if d.path.endswith(".so")]

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  for d in dep_runfiles:
    runfiles = runfiles.merge(d)

  golib = GoLibrary(
      label = ctx.label,
      importpath = importpath, # The import path for this library
      direct = direct, # The direct depencancies of the library
      transitive = transitive, # The transitive set of go libraries depended on
      srcs = depset(srcs), # The original sources
      cover_vars = cover_vars, # The cover variables for this library
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
      golib = golib,
      goembed = goembed,
      importable = importable,
      direct = direct_archives,
  )

  return [golib, goembed, goarchive]
