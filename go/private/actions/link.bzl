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
    "RACE_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "get_library",
    "get_searchpath",
)

def emit_link(ctx, go_toolchain, library, mode, executable, gc_linkopts, x_defs):
  """Adds an action to link the supplied library in the given mode, producing the executable.
  Args:
    ctx: The skylark Context.
    library: The library to link.
    mode: Controls the linking setup affecting things like enabling profilers and sanitizers.
      This must be one of the values in common.bzl#compile_modes
    executable: The binary to produce.
    gc_linkopts: basic link options, these may be adjusted by the mode.
    x_defs: link defines, including build stamping ones
  """

  # Add in any mode specific behaviours
  if mode == RACE_MODE:
    gc_linkopts += ["-race"]

  config_strip = len(ctx.configuration.bin_dir.path) + 1
  pkg_depth = executable.dirname[config_strip:].count('/') + 1

  ld = None
  extldflags = []
  if go_toolchain.external_linker:
    ld = go_toolchain.external_linker.compiler_executable
    extldflags = list(go_toolchain.external_linker.options)
  extldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth)]

  gc_linkopts, extldflags = _extract_extldflags(gc_linkopts, extldflags)

  link_opts = ["-L", "."]
  libs = depset()
  cgo_deps = depset()
  for golib in depset([library]) + library.transitive:
    libs += [get_library(golib, mode)]
    link_opts += ["-L", get_searchpath(golib, mode)]
    cgo_deps += golib.cgo_deps

  for d in cgo_deps:
    if d.basename.endswith('.so'):
      short_dir = d.dirname[len(d.root.path):]
      extldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth) + short_dir]

  link_opts += ["-o", executable.path] + gc_linkopts

  # Process x_defs, either adding them directly to linker options, or
  # saving them to process through stamping support.
  stamp_x_defs = {}
  for k, v in x_defs.items():
    if v.startswith("{") and v.endswith("}"):
      stamp_x_defs[k] = v[1:-1]
    else:
      link_opts += ["-X", "%s=%s" % (k, v)]

  link_opts += go_toolchain.flags.link
  if ld: 
    link_opts += [
        "-extld", ld,
        "-extldflags", " ".join(extldflags),
    ]
  link_opts += [get_library(golib, mode).path]
  link_args = [go_toolchain.tools.go.path]
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
      inputs = list(libs + cgo_deps +
                go_toolchain.data.tools + go_toolchain.data.crosstool + stamp_inputs),
      outputs = [executable],
      mnemonic = "GoLink",
      executable = go_toolchain.tools.link,
      arguments = link_args,
      env = go_toolchain.env,
  )

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

