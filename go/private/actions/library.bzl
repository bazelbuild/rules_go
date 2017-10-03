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
    "compile_modes",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "CgoInfo",
    "GoLibrary",
    "GoEmbed",
    "library_attr",
    "searchpath_attr",
)

def emit_library(ctx, go_toolchain,
    importpath = "",
    srcs = (),
    deps = (),
    cgo_info = None,
    embed = (),
    want_coverage = False,
    importable = True,
    golibs=()):
  """See go/toolchains.rst#library for full documentation."""
  dep_runfiles = [d.data_runfiles for d in deps]
  direct = depset(golibs)
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
    srcs = getattr(goembed, "srcs", depset()) + srcs
    build_srcs = getattr(goembed, "build_srcs", depset()) + build_srcs
    cover_vars += getattr(goembed, "cover_vars", ())
    direct += getattr(goembed, "deps", ())
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

  extra_objects = []
  for src in source.asm:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    go_toolchain.actions.asm(ctx, go_toolchain, src, source.headers, obj)
    extra_objects += [obj]
  archive = cgo_info.archive if cgo_info else None

  for dep in deps:
    direct += [dep[GoLibrary]]

  transitive = depset()
  for golib in direct:
    transitive += [golib]
    transitive += golib.transitive

  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, go_srcs)
    cover_vars += cvars

  lib_name = importpath + ".a"
  compilepath = importpath if importable else None
  mode_fields = {} # These are added to the GoLibrary provider directly
  for mode in compile_modes:
    out_dir = "~{}~{}~".format(mode, ctx.label.name)
    out_lib = ctx.new_file("{}/{}".format(out_dir, lib_name))
    searchpath = out_lib.path[:-len(lib_name)]
    mode_fields[library_attr(mode)] = out_lib
    mode_fields[searchpath_attr(mode)] = searchpath
    if len(extra_objects) == 0 and archive == None:
      go_toolchain.actions.compile(ctx,
          go_toolchain = go_toolchain,
          sources = go_srcs,
          importpath = compilepath,
          golibs = direct,
          mode = mode,
          out_lib = out_lib,
          gc_goopts = gc_goopts,
      )
    else:
      partial_lib = ctx.new_file("{}/~partial.a".format(out_dir))
      go_toolchain.actions.compile(ctx,
          go_toolchain = go_toolchain,
          sources = go_srcs,
          importpath = compilepath,
          golibs = direct,
          mode = mode,
          out_lib = partial_lib,
          gc_goopts = gc_goopts,
      )
      go_toolchain.actions.pack(ctx,
          go_toolchain = go_toolchain,
          in_lib = partial_lib,
          out_lib = out_lib,
          objects = extra_objects,
          archive = archive,
      )

  dylibs = []
  cgo_deps = depset()
  if cgo_info:
    dylibs += [d for d in cgo_info.deps if d.path.endswith(".so")]
    cgo_deps = cgo_info.deps

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  for d in dep_runfiles:
    runfiles = runfiles.merge(d)

  transformed = dict_of(source)
  transformed["go"] = go_srcs

  return [
      GoLibrary(
          label = ctx.label,
          importpath = importpath, # The import path for this library
          direct = direct, # The direct depencancies of the library
          transitive = transitive, # The transitive set of go libraries depended on
          srcs = depset(srcs), # The original sources
          cover_vars = cover_vars, # The cover variables for this library
          cgo_deps = cgo_deps, # The direct dependencies of the cgo code
          runfiles = runfiles, # The runfiles needed for things including this library
          **mode_fields
      ),
      GoEmbed(
          srcs = srcs, # The original sources
          build_srcs = join_srcs(struct(**transformed)), # The transformed sources actually compiled
          deps = direct, # The direct depencancies of the library
          cover_vars = cover_vars, # The cover variables for these sources
          cgo_info = cgo_info, # The cgo information for this library or one of its embeds.
          gc_goopts = gc_goopts, # The options this library was compiled with
      ),
  ]
