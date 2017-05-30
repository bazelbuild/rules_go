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

load("//go/private:common.bzl", "get_go_toolchain", "go_library_attrs", "crosstool_attrs", "go_link_attrs", "emit_generate_params_action")
load("//go/private:library.bzl", "go_library_impl")

def go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  lib_result = go_library_impl(ctx)
  emit_go_link_action(
    ctx,
    transitive_go_libraries=lib_result.transitive_go_libraries,
    transitive_go_library_paths=lib_result.transitive_go_library_paths,
    cgo_deps=lib_result.transitive_cgo_deps,
    libs=lib_result.files,
    executable=ctx.outputs.executable,
    gc_linkopts=gc_linkopts(ctx))

  return struct(
      files = depset([ctx.outputs.executable]),
      runfiles = lib_result.runfiles,
      cgo_object = lib_result.cgo_object,
  )

go_binary = rule(
    go_binary_impl,
    attrs = go_library_attrs + crosstool_attrs + go_link_attrs,
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
  for k, v in ctx.attr.x_defs.items():
    gc_linkopts += ["-X", "%s='%s'" % (k, v)]
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
                         executable, gc_linkopts):
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

  link_cmd = [
      go_toolchain.go.path,
      "tool", "link",
      "-L", "."
  ]
  for path in transitive_go_library_paths:
    link_cmd += ["-L", path]
  link_cmd += [
      "-o", executable.path,
  ] + gc_linkopts + ['"${STAMP_XDEFS[@]}"']

  link_cmd += go_toolchain.link_flags + [
      "-extld", ld,
      "-extldflags", "'%s'" % " ".join(extldflags),
  ] + [lib.path for lib in libs]

  # Avoided -s on OSX but but it requires dsymutil to be on $PATH.
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  cmds = ["export PATH=$PATH:/usr/bin"]

  cmds += [
      "STAMP_XDEFS=()",
  ]

  stamp_inputs = []
  if ctx.attr.linkstamp:
    # read workspace status files, converting "KEY value" lines
    # to "-X $linkstamp.KEY=value" arguments to the go linker.
    stamp_inputs = [ctx.info_file, ctx.version_file]
    for f in stamp_inputs:
      cmds += [
          "while read -r key value || [[ -n $key ]]; do",
          "  STAMP_XDEFS+=(-X \"%s.$key=$value\")" % ctx.attr.linkstamp,
          "done < " + f.path,
      ]

  cmds += [' '.join(link_cmd)]

  f = emit_generate_params_action(cmds, ctx, lib.basename + ".GoLinkFile.params")

  ctx.action(
      inputs = [f] + (list(transitive_go_libraries) + [lib] + list(cgo_deps) +
                go_toolchain.tools + ctx.files._crosstool) + stamp_inputs,
      outputs = [executable],
      command = f.path,
      mnemonic = "GoLink",
      env = go_toolchain.env,
  )

