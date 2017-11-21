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
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
    "mode_string",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoSources",
    "GoArchive",
    "GoArchiveData",
    "sources",
)


GoAspectArchive = provider()

def get_archive(dep):
  if GoAspectArchive in dep:
    return dep[GoAspectArchive].archive
  return dep[GoArchive]

def _go_archive_aspect_impl(target, ctx):
  mode = get_mode(ctx, ctx.rule.attr._go_toolchain_flags)
  if GoArchive not in target:
    return []
  goarchive = target[GoArchive]
  if goarchive.mode == mode:
    return [GoAspectArchive(archive = goarchive)]

  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  goarchive = go_toolchain.actions.archive(ctx,
      go_toolchain = go_toolchain,
      mode = mode,
      importpath = target[GoLibrary].package.importpath,
      source = target[GoSources],
      importable = True,
  )
  return [GoAspectArchive(archive = goarchive)]

go_archive_aspect = aspect(
    _go_archive_aspect_impl,
    attr_aspects = ["deps", "embed"],
    attrs = {
        "pure": attr.string(values=["on", "off", "auto"], default="auto"),
        "static": attr.string(values=["on", "off", "auto"], default="auto"),
        "msan": attr.string(values=["on", "off", "auto"], default="auto"),
        "race": attr.string(values=["on", "off", "auto"], default="auto"),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def emit_archive(ctx, go_toolchain, mode=None, importpath=None, source=None, importable=True):
  """See go/toolchains.rst#archive for full documentation."""

  if not importpath: fail("golib is a required parameter")
  if source == None: fail("source is a required parameter")
  if mode == None: fail("mode is a required parameter")

  flat = sources.flatten(ctx, source)
  split = split_srcs(flat.build_srcs)
  lib_name = importpath + ".a"
  compilepath = importpath if importable else None
  out_dir = "~{}~{}~".format(mode_string(mode), ctx.label.name)
  out_lib = ctx.actions.declare_file("{}/{}".format(out_dir, lib_name))
  searchpath = out_lib.path[:-len(lib_name)]

  extra_objects = []
  for src in split.asm:
    obj = ctx.actions.declare_file("{}/{}.o".format(out_dir, src.basename[:-2]))
    go_toolchain.actions.asm(ctx, go_toolchain, mode=mode, source=src, hdrs=split.headers, out_obj=obj)
    extra_objects.append(obj)

  direct = [get_archive(dep) for dep in flat.deps]
  runfiles = flat.runfiles
  for a in direct:
    runfiles = runfiles.merge(a.runfiles)
    if a.mode != mode: fail("Archive mode does not match {} is {} expected {}".format(a.data.importpath, mode_string(a.mode), mode_string(mode)))

  cover_vars = ["{}={}".format(var, importpath) for var in flat.cover_vars]

  if len(extra_objects) == 0 and flat.cgo_archive == None:
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        mode = mode,
        out_lib = out_lib,
        gc_goopts = flat.gc_goopts,
    )
  else:
    partial_lib = ctx.actions.declare_file("{}/~partial.a".format(out_dir))
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = split.go,
        importpath = compilepath,
        archives = direct,
        mode = mode,
        out_lib = partial_lib,
        gc_goopts = flat.gc_goopts,
    )
    go_toolchain.actions.pack(ctx,
        go_toolchain = go_toolchain,
        mode = mode,
        in_lib = partial_lib,
        out_lib = out_lib,
        objects = extra_objects,
        archive = flat.cgo_archive,
    )
  data = GoArchiveData(
      file = out_lib,
      importpath = importpath,
      searchpath = searchpath,
  )
  return GoArchive(
      mode = mode,
      data = data,
      go_srcs = split.go,
      direct = direct,
      searchpaths = sets.union([searchpath], *[a.searchpaths for a in direct]),
      libs = sets.union([out_lib], *[a.libs for a in direct]),
      cgo_deps = sets.union(flat.cgo_deps, *[a.cgo_deps for a in direct]),
      cgo_exports = sets.union(flat.cgo_exports, *[a.cgo_exports for a in direct]),
      cover_vars = sets.union(cover_vars, *[a.cover_vars for a in direct]),
      runfiles = runfiles,
  )
