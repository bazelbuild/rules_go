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
    "NORMAL_MODE",
    "RACE_MODE",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "get_library",
    "get_searchpath",
)

def emit_compile(ctx, go_toolchain,
    sources = None,
    importpath = "",
    golibs = [],
    mode = NORMAL_MODE,
    out_lib = None,
    gc_goopts = []):
  """See go/toolchains.rst#compile for full documentation."""

  if sources == None: fail("sources is a required parameter")
  if out_lib == None: fail("out_lib is a required parameter")

  # Add in any mode specific behaviours
  if mode == RACE_MODE:
    gc_goopts = gc_goopts + ("-race",)

  gc_goopts = [ctx.expand_make_variables("gc_goopts", f, {}) for f in gc_goopts]
  inputs = depset([go_toolchain.tools.go]) + sources
  go_sources = [s.path for s in sources if not s.basename.startswith("_cgo")]
  cgo_sources = [s.path for s in sources if s.basename.startswith("_cgo")]
  args = [go_toolchain.tools.go.path]
  for src in go_sources:
    args += ["-src", src]
  for golib in golibs:
    inputs += [get_library(golib, mode)]
    args += ["-dep", golib.importpath]
    args += ["-I", get_searchpath(golib,mode)]
  args += ["-o", out_lib.path, "-trimpath", ".", "-I", "."]
  args += ["--"]
  if importpath:
    args += ["-p", importpath]
  args.extend(gc_goopts)
  args.extend(go_toolchain.flags.compile)
  if ctx.attr._go_toolchain_flags.compilation_mode == "debug":
    args.extend(["-N", "-l"])
  args.extend(cgo_sources)
  ctx.action(
      inputs = list(inputs),
      outputs = [out_lib],
      mnemonic = "GoCompile",
      executable = go_toolchain.tools.compile,
      arguments = args,
      env = go_toolchain.env,
  )
