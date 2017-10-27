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
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "mode_string",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoArchive",
)

def emit_archive(ctx, go_toolchain,
    importpath = "",
    srcs = (),
    direct = (),
    cgo_info = None,
    importable = True,
    mode = None,
    gc_goopts = ()):
  """See go/toolchains.rst#archive for full documentation."""

  source = split_srcs(srcs)
  lib_name = importpath + ".a"
  compilepath = importpath if importable else None
  out_dir = "~{}~{}~".format(mode_string(mode), ctx.label.name)
  out_lib = ctx.new_file("{}/{}".format(out_dir, lib_name))
  searchpath = out_lib.path[:-len(lib_name)]

  extra_objects = []
  for src in source.asm:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    go_toolchain.actions.asm(ctx, go_toolchain, src, source.headers, obj)
    extra_objects += [obj]
  archive = cgo_info.archive if cgo_info else None

  if len(extra_objects) == 0 and archive == None:
    go_toolchain.actions.compile(ctx,
        go_toolchain = go_toolchain,
        sources = source.go,
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
        sources = source.go,
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

  return GoArchive(
      lib = out_lib,
      mode = mode,
      searchpath = searchpath,
  )
