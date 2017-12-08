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
    "declare_file",
    "split_srcs",
    "sets",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "mode_string",
)
load("@io_bazel_rules_go//go/private:rules/helpers.bzl",
    "get_archive",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoArchive",
    "GoArchiveData",
)

def emit_archive(ctx, go_toolchain, source=None):
  """See go/toolchains.rst#archive for full documentation."""

  if source == None: fail("source is a required parameter")

  cover_vars = []
  if ctx.configuration.coverage_enabled:
    source, cover_vars = go_toolchain.actions.cover(ctx, go_toolchain, source)
  split = split_srcs(source.srcs)
  compilepath = source.library.importpath if source.library.importpath else source.library.name
  lib_name = compilepath + ".a"
  out_lib = declare_file(ctx, path=lib_name, mode=source.mode)
  searchpath = out_lib.path[:-len(lib_name)]

  extra_objects = []
  for src in split.asm:
    obj = declare_file(ctx, path=src.basename[:-2], ext=".o", mode=source.mode)
    go_toolchain.actions.asm(ctx, go_toolchain, mode=source.mode, source=src, hdrs=split.headers, out_obj=obj)
    extra_objects.append(obj)

  direct = [get_archive(dep) for dep in source.deps]
  runfiles = source.runfiles
  for a in direct:
    runfiles = runfiles.merge(a.runfiles)
    if a.source.mode != source.mode: fail("Archive mode does not match {} is {} expected {}".format(a.data.source.library.label, mode_string(a.source.mode), mode_string(source.mode)))

  if len(extra_objects) == 0 and source.cgo_archive == None:
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        mode = source.mode,
        out_lib = out_lib,
        gc_goopts = source.gc_goopts,
    )
  else:
    partial_lib = declare_file(ctx, path="partial", ext=".a", mode=source.mode)
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        mode = source.mode,
        out_lib = partial_lib,
        gc_goopts = source.gc_goopts,
    )
    go_toolchain.actions.pack(ctx,
        go_toolchain = go_toolchain,
        mode = source.mode,
        in_lib = partial_lib,
        out_lib = out_lib,
        objects = extra_objects,
        archive = source.cgo_archive,
    )
  data = GoArchiveData(
      name = source.library.name,
      label = source.library.label,
      importpath = source.library.importpath,
      exportpath = source.library.exportpath,
      file = out_lib,
      srcs = tuple(source.srcs),
      searchpath = searchpath,
  )
  return GoArchive(
      source = source,
      data = data,
      direct = direct,
      searchpaths = sets.union([searchpath], *[a.searchpaths for a in direct]),
      libs = sets.union([out_lib], *[a.libs for a in direct]),
      transitive = sets.union([data], *[a.transitive for a in direct]),
      cgo_deps = sets.union(source.cgo_deps, *[a.cgo_deps for a in direct]),
      cgo_exports = sets.union(source.cgo_exports, *[a.cgo_exports for a in direct]),
      cover_vars = sets.union(cover_vars, *[a.cover_vars for a in direct]),
      runfiles = runfiles,
  )
