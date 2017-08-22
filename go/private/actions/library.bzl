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
    "GoLibrary", 
    "CgoLibrary",
    "library_attr",
    "searchpath_attr",
)

def emit_library(ctx, go_toolchain, srcs, deps, cgo_object, library, want_coverage, importpath, golibs=[]):
  dep_runfiles = [d.data_runfiles for d in deps]
  direct = depset(golibs)
  gc_goopts = tuple(ctx.attr.gc_goopts)
  cgo_deps = depset()
  cover_vars = ()
  if library:
    golib = library[GoLibrary]
    cgolib = library[CgoLibrary]
    srcs = golib.transformed + srcs
    cover_vars += golib.cover_vars
    direct += golib.direct
    dep_runfiles += [library.data_runfiles]
    gc_goopts += golib.gc_goopts
    cgo_deps += golib.cgo_deps
    if cgolib.object:
      if cgo_object:
        fail("go_library %s cannot have cgo_object because the package " +
             "already has cgo_object in %s" % (ctx.label.name,
                                               golib.name))
      cgo_object = cgolib.object
  source = split_srcs(srcs)
  if source.c:
    fail("c sources in non cgo rule")
  if not source.go:
    fail("no go sources")

  if cgo_object:
    dep_runfiles += [cgo_object.data_runfiles]
    cgo_deps += cgo_object.cgo_deps

  extra_objects = [cgo_object.cgo_obj] if cgo_object else []
  for src in source.asm:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    go_toolchain.actions.asm(ctx, go_toolchain, src, source.headers, obj)
    extra_objects += [obj]

  for dep in deps:
    direct += [dep[GoLibrary]]

  transitive = depset()
  for golib in direct:
    transitive += [golib]
    transitive += golib.transitive

  go_srcs = source.go
  if want_coverage:
    go_srcs, cvars = go_toolchain.actions.cover(ctx, go_toolchain, go_srcs)
    cover_vars += cvars

  lib_name = importpath + ".a"
  mode_fields = {} # These are added to the GoLibrary provider directly
  for mode in compile_modes:
    out_lib = ctx.new_file("~{}~{}~/{}".format(mode, ctx.label.name, lib_name))
    out_object = ctx.new_file("~{}~{}~/{}.o".format(mode, ctx.label.name, importpath))
    searchpath = out_lib.path[:-len(lib_name)]
    mode_fields[library_attr(mode)] = out_lib
    mode_fields[searchpath_attr(mode)] = searchpath
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = go_srcs,
        golibs = direct,
        mode = mode,
        out_object = out_object,
        gc_goopts = gc_goopts,
    )
    go_toolchain.actions.pack(ctx, go_toolchain, out_lib, [out_object] + extra_objects)

  dylibs = []
  if cgo_object:
    dylibs += [d for d in cgo_object.cgo_deps if d.path.endswith(".so")]

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
          transformed = join_srcs(struct(**transformed)), # The transformed sources actually compiled
          cgo_deps = cgo_deps, # The direct cgo dependencies of this library
          gc_goopts = gc_goopts, # The options this library was compiled with
          runfiles = runfiles, # The runfiles needed for things including this library
          cover_vars = cover_vars, # The cover variables for this library
          **mode_fields
      ),
      CgoLibrary(
          object = cgo_object,
      ),
  ]
