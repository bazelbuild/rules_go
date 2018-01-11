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
    "sets",
)

def _importpath(l):
  return [v.data.importpath for v in l]

def _searchpath(l):
  return [v.data.searchpath for v in l]

def emit_compile(go,
    sources = None,
    importpath = "",
    archives = [],
    out_lib = None,
    gc_goopts = []):
  """See go/toolchains.rst#compile for full documentation."""

  if sources == None: fail("sources is a required parameter")
  if out_lib == None: fail("out_lib is a required parameter")

  # Add in any mode specific behaviours
  if go.mode.race:
    gc_goopts = gc_goopts + ["-race"]
  if go.mode.msan:
    gc_goopts = gc_goopts + ["-msan"]

  #TODO: Check if we really need this expand make variables in here
  #TODO: If we really do then it needs to be moved all the way back out to the rule
  gc_goopts = [go._ctx.expand_make_variables("gc_goopts", f, {}) for f in gc_goopts]
  inputs = sets.union(sources, [go.package_list])
  go_sources = [s.path for s in sources if not s.basename.startswith("_cgo")]
  cgo_sources = [s.path for s in sources if s.basename.startswith("_cgo")]

  inputs = sets.union(inputs, [archive.data.file for archive in archives])
  inputs = sets.union(inputs, go.stdlib.files)

  args = go.args(go)
  args.add(["-package_list", go.package_list])
  args.add(go_sources, before_each="-src")
  args.add(archives, before_each="-dep", map_fn=_importpath)
  args.add(archives, before_each="-I", map_fn=_searchpath)
  args.add(["-o", out_lib, "-trimpath", ".", "-I", "."])
  args.add(["--"])
  if importpath:
    args.add(["-p", importpath])
  args.add(gc_goopts)
  args.add(go.toolchain.flags.compile)
  if go.mode.debug:
    args.add(["-N", "-l"])
  args.add(cgo_sources)
  go.actions.run(
      inputs = inputs,
      outputs = [out_lib],
      mnemonic = "GoCompile",
      executable = go.toolchain.tools.compile,
      arguments = [args],
  )

def bootstrap_compile(go,
    sources = None,
    importpath = "",
    archives = [],
    out_lib = None,
    gc_goopts = []):
  """See go/toolchains.rst#compile for full documentation."""

  if sources == None: fail("sources is a required parameter")
  if out_lib == None: fail("out_lib is a required parameter")
  if archives:  fail("compile does not accept deps in bootstrap mode")

  args = ["tool", "compile", "-trimpath", "$(pwd)", "-o", out_lib.path]
  args.extend(gc_goopts)
  args.extend([s.path for s in sources])
  go.actions.run_shell(
      inputs = sources + go.sdk_files + go.sdk_tools,
      outputs = [out_lib],
      mnemonic = "GoCompile",
      command = "export GOROOT=$(pwd)/{} && export GOROOT_FINAL=GOROOT && {} {}".format(go.root, go.go.path, " ".join(args)),
  )
