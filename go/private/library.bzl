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

load("//go/private:common.bzl", "get_go_toolchain", "go_library_attrs", "DEFAULT_LIB", "VENDOR_PREFIX")
load("//go/private:asm.bzl", "emit_go_asm_action")

def go_library_impl(ctx):
  """Implements the go_library() rule."""
  go_toolchain = get_go_toolchain(ctx)
  sources = set(ctx.files.srcs)
  go_srcs = set([s for s in sources if s.basename.endswith('.go')])
  asm_srcs = [s for s in sources if s.basename.endswith('.s') or s.basename.endswith('.S')]
  asm_hdrs = [s for s in sources if s.basename.endswith('.h')]
  deps = ctx.attr.deps
  dep_runfiles = [d.data_runfiles for d in deps]

  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object

  if ctx.attr.library:
    go_srcs += ctx.attr.library.go_sources
    asm_srcs += ctx.attr.library.asm_sources
    asm_hdrs += ctx.attr.library.asm_headers
    deps += ctx.attr.library.direct_deps
    dep_runfiles += [ctx.attr.library.data_runfiles]
    if ctx.attr.library.cgo_object:
      if cgo_object:
        fail("go_library %s cannot have cgo_object because the package " +
             "already has cgo_object in %s" % (ctx.label.name,
                                               ctx.attr.library.name))
      cgo_object = ctx.attr.library.cgo_object
  if not go_srcs:
    fail("may not be empty", "srcs")

  transitive_cgo_deps = set([], order="link")
  if cgo_object:
    dep_runfiles += [cgo_object.data_runfiles]
    transitive_cgo_deps += cgo_object.cgo_deps

  extra_objects = [cgo_object.cgo_obj] if cgo_object else []
  for src in asm_srcs:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    emit_go_asm_action(ctx, src, asm_hdrs, obj)
    extra_objects += [obj]

  lib_name = go_importpath(ctx) + ".a"
  out_lib = ctx.new_file(lib_name)
  out_object = ctx.new_file(ctx.label.name + ".o")
  search_path = out_lib.path[:-len(lib_name)]
  gc_goopts = get_gc_goopts(ctx)
  transitive_go_libraries = depset([out_lib])
  transitive_go_library_paths = depset([search_path])
  for dep in deps:
    transitive_go_libraries += dep.transitive_go_libraries
    transitive_cgo_deps += dep.transitive_cgo_deps
    transitive_go_library_paths += dep.transitive_go_library_paths

  go_srcs = emit_go_compile_action(ctx,
      sources = go_srcs,
      deps = deps,
      libpaths = transitive_go_library_paths,
      out_object = out_object,
      gc_goopts = gc_goopts,
  )
  emit_go_pack_action(ctx, out_lib, [out_object] + extra_objects)

  dylibs = []
  if cgo_object:
    dylibs += [d for d in cgo_object.cgo_deps if d.path.endswith(".so")]

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  for d in dep_runfiles:
    runfiles = runfiles.merge(d)

  return struct(
    label = ctx.label,
    files = set([out_lib]),
    runfiles = runfiles,
    go_sources = go_srcs,
    asm_sources = asm_srcs,
    asm_headers = asm_hdrs,
    cgo_object = cgo_object,
    direct_deps = ctx.attr.deps,
    transitive_cgo_deps = transitive_cgo_deps,
    transitive_go_libraries = transitive_go_libraries,
    transitive_go_library_paths = transitive_go_library_paths,
    gc_goopts = gc_goopts,
  )

go_library = rule(
    go_library_impl,
    attrs = go_library_attrs + {
        "cgo_object": attr.label(
            providers = [
                "cgo_obj",
                "cgo_deps",
            ],
        ),
    },
    fragments = ["cpp"],
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
  if ctx.label.name != DEFAULT_LIB:
    path += "/" + ctx.label.name
  if path.rfind(VENDOR_PREFIX) != -1:
    path = path[len(VENDOR_PREFIX) + path.rfind(VENDOR_PREFIX):]
  if path[0] == "/":
    path = path[1:]
  return path

def get_gc_goopts(ctx):
  gc_goopts = [ctx.expand_make_variables("gc_goopts", f, {})
               for f in ctx.attr.gc_goopts]
  if ctx.attr.library:
    gc_goopts += ctx.attr.library.gc_goopts
  return gc_goopts

def emit_go_compile_action(ctx, sources, deps, libpaths, out_object, gc_goopts):
  """Construct the command line for compiling Go code.

  Args:
    ctx: The skylark Context.
    sources: an iterable of source code artifacts (or CTs? or labels?)
    deps: an iterable of dependencies. Each dependency d should have an
      artifact in d.transitive_go_libraries representing all imported libraries.
    libpaths: the set of paths to search for imported libraries.
    out_object: the object file that should be produced
    gc_goopts: additional flags to pass to the compiler.
  """
  go_toolchain = get_go_toolchain(ctx)
  if ctx.coverage_instrumented():
    sources = _emit_go_cover_action(ctx, sources)

  # Compile filtered files.
  args = [
      "-cgo",
      go_toolchain.go.path,
      "tool", "compile",
      "-o", out_object.path,
      "-trimpath", "-abs-.",
      "-I", "-abs-.",
  ]
  inputs = depset(sources + [go_toolchain.go])
  for dep in deps:
    inputs += dep.transitive_go_libraries
  for path in libpaths:
    args += ["-I", path]
  args += gc_goopts + [("" if i.basename.startswith("_cgo") else "-filter-") + i.path for i in sources]
  ctx.action(
      inputs = list(inputs),
      outputs = [out_object],
      mnemonic = "GoCompile",
      executable = go_toolchain.filter_exec,
      arguments = args,
      env = go_toolchain.env,
  )

  return sources

def emit_go_pack_action(ctx, out_lib, objects):
  """Construct the command line for packing objects together.

  Args:
    ctx: The skylark Context.
    out_lib: the archive that should be produced
    objects: an iterable of object files to be added to the output archive file.
  """
  go_toolchain = get_go_toolchain(ctx)
  ctx.action(
      inputs = objects + go_toolchain.tools,
      outputs = [out_lib],
      mnemonic = "GoPack",
      executable = go_toolchain.go,
      arguments = ["tool", "pack", "c", out_lib.path] + [a.path for a in objects],
      env = go_toolchain.env,
  )

def _emit_go_cover_action(ctx, sources):
  """Construct the command line for test coverage instrument.

  Args:
    ctx: The skylark Context.
    sources: an iterable of Go source files.

  Returns:
    A list of Go source code files which might be coverage instrumented.
  """
  go_toolchain = get_go_toolchain(ctx)
  outputs = []
  # TODO(linuxerwang): make the mode configurable.
  count = 0

  for src in sources:
    if not src.path.endswith(".go") or src.path.endswith("_test.go"):
      outputs += [src]
      continue

    cover_var = "GoCover_%d" % count
    out = ctx.new_file(src, src.basename[:-3] + '_' + cover_var + '.cover.go')
    outputs += [out]
    ctx.action(
        inputs = [src] + go_toolchain.tools,
        outputs = [out],
        mnemonic = "GoCover",
        executable = go_toolchain.go,
        arguments = ["tool", "cover", "--mode=set", "-var=%s" % cover_var, "-o", out.path, src.path],
        env = go_toolchain.env,
    )
    count += 1

  return outputs
