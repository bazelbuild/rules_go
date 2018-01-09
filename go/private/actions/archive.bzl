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
    "@io_bazel_rules_go//go/private:common.bzl",
    "split_srcs",
    "sets",
    "as_tuple",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "mode_string",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoArchive",
    "GoArchiveData",
    "get_archive",
)

def emit_archive(go, source=None):
  """See go/toolchains.rst#archive for full documentation."""

  if source == None: fail("source is a required parameter")

  cover_vars = []
  if go.cover:
    source, cover_vars = go.cover(go, source)
  split = split_srcs(source.srcs)
  compilepath = source.library.importpath if source.library.importpath else source.library.name
  lib_name = compilepath + ".a"
  out_lib = go.declare_file(go, path=lib_name)
  searchpath = out_lib.path[:-len(lib_name)]

  extra_objects = []
  for src in split.asm:
    extra_objects.append(go.asm(go, source=src, hdrs=split.headers))

  direct = [get_archive(dep) for dep in source.deps]
  runfiles = source.runfiles
  for a in direct:
    runfiles = runfiles.merge(a.runfiles)
    if a.source.mode != go.mode: fail("Archive mode does not match {} is {} expected {}".format(a.data.label, mode_string(a.source.mode), mode_string(go.mode)))

  if len(extra_objects) == 0 and source.cgo_archive == None:
    go.compile(go,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        out_lib = out_lib,
        gc_goopts = source.gc_goopts,
    )
  else:
    partial_lib = go.declare_file(go, path="partial", ext=".a")
    go.compile(go,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        out_lib = partial_lib,
        gc_goopts = source.gc_goopts,
    )
    go.pack(go,
        in_lib = partial_lib,
        out_lib = out_lib,
        objects = extra_objects,
        archive = source.cgo_archive,
    )
  data = GoArchiveData(
      name = source.library.name,
      label = source.library.label,
      importpath = source.library.importpath,
      file = out_lib,
      srcs = as_tuple(source.srcs),
      searchpath = searchpath,
  )
  x_defs = dict(source.x_defs)
  for a in direct:
    x_defs.update(a.x_defs)
  return GoArchive(
      source = source,
      data = data,
      direct = direct,
      searchpaths = sets.union([searchpath], *[a.searchpaths for a in direct]),
      libs = sets.union([out_lib], *[a.libs for a in direct]),
      transitive = sets.union([data], *[a.transitive for a in direct]),
      x_defs = x_defs,
      cgo_deps = sets.union(source.cgo_deps, *[a.cgo_deps for a in direct]),
      cgo_exports = sets.union(source.cgo_exports, *[a.cgo_exports for a in direct]),
      cover_vars = sets.union(cover_vars, *[a.cover_vars for a in direct]),
      runfiles = runfiles,
  )
