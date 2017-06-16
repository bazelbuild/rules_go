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

load("@io_bazel_rules_go//go/private:common.bzl", "get_go_toolchain", "go_filetype")
load("@io_bazel_rules_go//go/private:library.bzl", "emit_library_actions")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoBinary")

def _go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  lib_result = emit_library_actions(ctx,
      sources = depset(ctx.files.srcs),
      deps = ctx.attr.deps,
      cgo_object = None,
      library = ctx.attr.library,
  )

  # Default (dynamic) linking
  emit_go_link_action(
    ctx,
    transitive_go_libraries=lib_result.transitive_go_libraries,
    transitive_go_library_paths=lib_result.transitive_go_library_paths,
    cgo_deps=lib_result.transitive_cgo_deps,
    libs=lib_result.files,
    executable=ctx.outputs.executable,
    gc_linkopts=gc_linkopts(ctx),
    x_defs=ctx.attr.x_defs)

  # Static linking (in the 'static' output group)
  static_linkopts = [
      "-linkmode", "external",
      "-extldflags", "-static",
  ]
  static_executable = ctx.new_file(ctx.attr.name + ".static")
  emit_go_link_action(
    ctx,
    transitive_go_libraries=lib_result.transitive_go_libraries,
    transitive_go_library_paths=lib_result.transitive_go_library_paths,
    cgo_deps=lib_result.transitive_cgo_deps,
    libs=lib_result.files,
    executable=static_executable,
    gc_linkopts=gc_linkopts(ctx) + static_linkopts,
    x_defs=ctx.attr.x_defs)

  return [
      GoBinary(
          executable = ctx.outputs.executable,
          static = static_executable,
          cgo_object = lib_result.cgo_object,
      ),
      DefaultInfo(
          files = depset([ctx.outputs.executable]),
          runfiles = lib_result.runfiles,
      ),
      OutputGroupInfo(
          static = depset([static_executable]),
      ),
  ]

go_binary = rule(
    _go_binary_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "srcs": attr.label_list(allow_files = go_filetype),
        "deps": attr.label_list(providers = [GoLibrary]),
        "importpath": attr.string(),
        "library": attr.label(providers = [GoLibrary]),
        "gc_goopts": attr.string_list(),
        "gc_linkopts": attr.string_list(),
        "linkstamp": attr.string(),
        "x_defs": attr.string_dict(),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
        "_go_prefix": attr.label(default = Label(
            "//:go_prefix",
            relative_to_caller_repository = True,
        )),
    },
    executable = True,
    fragments = ["cpp"],
)

def c_linker_options(ctx, blacklist=[]):
  """Extracts flags to pass to $(CC) on link from the current context

  Args:
    ctx: the current context
    blacklist: Any flags starts with any of these prefixes are filtered out from
      the return value.

  Returns:
    A list of command line flags
  """
  cpp = ctx.fragments.cpp
  features = ctx.features
  options = cpp.compiler_options(features)
  options += cpp.unfiltered_compiler_options(features)
  options += cpp.link_options
  options += cpp.mostly_static_link_options(ctx.features, False)
  filtered = []
  for opt in options:
    if any([opt.startswith(prefix) for prefix in blacklist]):
      continue
    filtered.append(opt)
  return filtered

def gc_linkopts(ctx):
  gc_linkopts = [ctx.expand_make_variables("gc_linkopts", f, {})
                 for f in ctx.attr.gc_linkopts]
  return gc_linkopts

def _extract_extldflags(gc_linkopts, extldflags):
  """Extracts -extldflags from gc_linkopts and combines them into a single list.

  Args:
    gc_linkopts: a list of flags passed in through the gc_linkopts attributes.
      ctx.expand_make_variables should have already been applied.
    extldflags: a list of flags to be passed to the external linker.

  Return:
    A tuple containing the filtered gc_linkopts with external flags removed,
    and a combined list of external flags.
  """
  filtered_gc_linkopts = []
  is_extldflags = False
  for opt in gc_linkopts:
    if is_extldflags:
      is_extldflags = False
      extldflags += [opt]
    elif opt == "-extldflags":
      is_extldflags = True
    else:
      filtered_gc_linkopts += [opt]
  return filtered_gc_linkopts, extldflags

def emit_go_link_action(ctx, transitive_go_library_paths, transitive_go_libraries, cgo_deps, libs,
                         executable, gc_linkopts, x_defs):
  """Sets up a symlink tree to libraries to link together."""
  go_toolchain = get_go_toolchain(ctx)
  config_strip = len(ctx.configuration.bin_dir.path) + 1
  pkg_depth = executable.dirname[config_strip:].count('/') + 1

  ld = "%s" % ctx.fragments.cpp.compiler_executable
  extldflags = c_linker_options(ctx) + [
      "-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth),
  ]
  for d in cgo_deps:
    if d.basename.endswith('.so'):
      short_dir = d.dirname[len(d.root.path):]
      extldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth) + short_dir]

  gc_linkopts, extldflags = _extract_extldflags(gc_linkopts, extldflags)

  link_opts = [
      "-L", "."
  ]
  for path in transitive_go_library_paths:
    link_opts += ["-L", path]
  link_opts += [
      "-o", executable.path,
  ] + gc_linkopts

  # Process x_defs, either adding them directly to linker options, or
  # saving them to process through stamping support.
  stamp_x_defs = {}
  for k, v in x_defs.items():
    if v.startswith("{") and v.endswith("}"):
      stamp_x_defs[k] = v[1:-1]
    else:
      link_opts += ["-X", "%s=%s" % (k, v)]

  link_opts += go_toolchain.link_flags + [
      "-extld", ld,
      "-extldflags", " ".join(extldflags),
  ] + [lib.path for lib in libs]

  link_args = [go_toolchain.go.path]
  # Stamping support
  stamp_inputs = []
  if stamp_x_defs or ctx.attr.linkstamp:
    stamp_inputs = [ctx.info_file, ctx.version_file]
    for f in stamp_inputs:
      link_args += ["-stamp", f.path]
    for k,v in stamp_x_defs.items():
      link_args += ["-X", "%s=%s" % (k, v)]
    # linkstamp option support: read workspace status files,
    # converting "KEY value" lines to "-X $linkstamp.KEY=value" arguments
    # to the go linker.
    if ctx.attr.linkstamp:
      link_args += ["-linkstamp", ctx.attr.linkstamp]

  link_args += ["--"] + link_opts

  ctx.action(
      inputs = list(transitive_go_libraries + [lib] + cgo_deps +
                go_toolchain.tools + go_toolchain.crosstool + stamp_inputs),
      outputs = [executable],
      mnemonic = "GoLink",
      executable = go_toolchain.link,
      arguments = link_args,
      env = go_toolchain.env,
  )