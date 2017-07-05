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
  "DEFAULT_LIB",
  "VENDOR_PREFIX",
  "go_filetype",
  "dict_of",
  "split_srcs",
  "join_srcs",
  "RACE_MODE",
  "NORMAL_MODE",
  "compile_modes",
)
load("@io_bazel_rules_go//go/private:asm.bzl", "emit_go_asm_action")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "CgoLibrary")

def emit_library_actions(ctx, go_toolchain, srcs, deps, cgo_object, library, want_coverage, importpath, golibs=[]):
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
    emit_go_asm_action(ctx, go_toolchain, src, source.headers, obj)
    extra_objects += [obj]

  for dep in deps:
    direct += [dep[GoLibrary]]

  transitive = depset()
  for golib in direct:
    transitive += [golib]
    transitive += golib.transitive

  go_srcs = source.go
  if want_coverage:
    go_srcs, cvars = _emit_go_cover_action(ctx, go_toolchain, go_srcs)
    cover_vars += cvars

  lib_name = importpath + ".a"
  mode_fields = {} # These are added to the GoLibrary provider directly
  for mode in compile_modes:
    out_lib = ctx.new_file("~{}~{}~/{}".format(mode, ctx.label.name, lib_name))
    out_object = ctx.new_file("~{}~{}~/{}.o".format(mode, ctx.label.name, importpath))
    searchpath = out_lib.path[:-len(lib_name)]
    mode_fields[mode+"_library"] = out_lib
    mode_fields[mode+"_searchpath"] = searchpath
    emit_go_compile_action(ctx,
        go_toolchain = go_toolchain,
        sources = go_srcs,
        golibs = direct,
        mode = mode,
        out_object = out_object,
        gc_goopts = gc_goopts,
    )
    emit_go_pack_action(ctx, go_toolchain, out_lib, [out_object] + extra_objects)

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
          cgo_deps = cgo_deps, # The direct cgo dependancies of this library
          gc_goopts = gc_goopts, # The options this library was compiled with
          runfiles = runfiles, # The runfiles needed for things including this library
          cover_vars = cover_vars, # The cover variables for this library
          **mode_fields
      ),
      CgoLibrary(
          object = cgo_object,
      ),
  ]

def get_library(golib, mode):
  """Returns the compiled library for the given mode"""
  # The attribute name must match the one assigned in emit_library_actions 
  return getattr(golib, mode+"_library")

def get_searchpath(golib, mode):
  """Returns the search path for the given mode"""
  # The attribute name must match the one assigned in emit_library_actions 
  return getattr(golib, mode+"_searchpath")

def _go_library_impl(ctx):
  """Implements the go_library() rule."""
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object
  golib, cgolib = emit_library_actions(ctx,
      go_toolchain = go_toolchain,
      srcs = ctx.files.srcs,
      deps = ctx.attr.deps,
      cgo_object = cgo_object,
      library = ctx.attr.library,
      want_coverage = ctx.coverage_instrumented(),
      importpath = go_importpath(ctx),
  )

  return [
      golib,
      cgolib,
      DefaultInfo(
          files = depset([get_library(golib, NORMAL_MODE)]),
          runfiles = golib.runfiles,
      ),
      OutputGroupInfo(
          race = depset([get_library(golib, RACE_MODE)]),
      ),
  ]

def go_prefix_default(importpath):
  return (None
          if importpath
          else Label("//:go_prefix", relative_to_caller_repository = True))

go_library = rule(
    _go_library_impl,
    attrs = {
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "cgo_object": attr.label(
            providers = [
                "cgo_obj",
                "cgo_deps",
            ],
        ),
        "_go_prefix": attr.label(default = go_prefix_default),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def go_importpath(ctx):
  """Returns the expected importpath of the go_library being built.

  Args:
    ctx: The skylark Context

  Returns:
    Go importpath of the library
  """
  path = ctx.attr.importpath
  if path != "":
    return path
  path = ctx.attr._go_prefix.go_prefix
  if path.endswith("/"):
    path = path[:-1]
  if ctx.label.package:
    path += "/" + ctx.label.package
  if ctx.label.name != DEFAULT_LIB and not path.endswith(ctx.label.name):
    path += "/" + ctx.label.name
  if path.rfind(VENDOR_PREFIX) != -1:
    path = path[len(VENDOR_PREFIX) + path.rfind(VENDOR_PREFIX):]
  if path[0] == "/":
    path = path[1:]
  return path

def emit_go_compile_action(ctx, go_toolchain, sources, golibs, mode, out_object, gc_goopts):
  """Construct the command line for compiling Go code.

  Args:
    ctx: The skylark Context.
    sources: an iterable of source code artifacts (or CTs? or labels?)
    golibs: a depset of representing all imported libraries.
    mode: Controls the compilation setup affecting things like enabling profilers and sanitizers.
      This must be one of the values in common.bzl#compile_modes
    out_object: the object file that should be produced
    gc_goopts: additional flags to pass to the compiler.
  """

  # Add in any mode specific behaviours
  if mode == RACE_MODE:
    gc_goopts = gc_goopts + ("-race",)

  gc_goopts = [ctx.expand_make_variables("gc_goopts", f, {}) for f in gc_goopts]
  inputs = depset([go_toolchain.go]) + sources
  go_sources = [s.path for s in sources if not s.basename.startswith("_cgo")]
  cgo_sources = [s.path for s in sources if s.basename.startswith("_cgo")]
  args = [go_toolchain.go.path]
  for src in go_sources:
    args += ["-src", src]
  for golib in golibs:
    inputs += [get_library(golib, mode)]
    args += ["-dep", golib.importpath]
    args += ["-I", get_searchpath(golib,mode)]
  args += ["-o", out_object.path, "-trimpath", ".", "-I", "."]
  args += ["--"] + gc_goopts + cgo_sources
  ctx.action(
      inputs = list(inputs),
      outputs = [out_object],
      mnemonic = "GoCompile",
      executable = go_toolchain.compile,
      arguments = args,
      env = go_toolchain.env,
  )

def emit_go_pack_action(ctx, go_toolchain, out_lib, objects):
  """Construct the command line for packing objects together.

  Args:
    ctx: The skylark Context.
    out_lib: the archive that should be produced
    objects: an iterable of object files to be added to the output archive file.
  """
  ctx.action(
      inputs = objects + go_toolchain.tools,
      outputs = [out_lib],
      mnemonic = "GoPack",
      executable = go_toolchain.go,
      arguments = ["tool", "pack", "c", out_lib.path] + [a.path for a in objects],
      env = go_toolchain.env,
  )

def _emit_go_cover_action(ctx, go_toolchain, sources):
  """Construct the command line for test coverage instrument.

  Args:
    ctx: The skylark Context.
    out_object: the object file for the library being compiled. Used to name
      cover files.
    sources: an iterable of Go source files.

  Returns:
    A list of Go source code files which might be coverage instrumented.
  """
  outputs = []
  # TODO(linuxerwang): make the mode configurable.
  cover_vars = []

  for src in sources:
    if (not src.basename.endswith(".go") or 
        src.basename.endswith("_test.go") or 
        src.basename.endswith(".cover.go")):
      outputs += [src]
      continue

    cover_var = "Cover_" + src.basename[:-3].replace("-", "_").replace(".", "_")
    cover_vars += ["{}={}".format(cover_var,src.short_path)]
    out = ctx.new_file(cover_var + '.cover.go')
    outputs += [out]
    ctx.action(
        inputs = [src] + go_toolchain.tools,
        outputs = [out],
        mnemonic = "GoCover",
        executable = go_toolchain.go,
        arguments = ["tool", "cover", "--mode=set", "-var=%s" % cover_var, "-o", out.path, src.path],
        env = go_toolchain.env,
    )

  return outputs, tuple(cover_vars)
