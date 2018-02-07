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

def emit_asm(go,
    source = None,
    hdrs = []):
  """See go/toolchains.rst#asm for full documentation."""

  if source == None: fail("source is a required parameter")

  out_obj = go.declare_file(go, path=source.basename[:-2], ext=".o")
  includes = sets.union(
      [go.stdlib.root_file.dirname + "/pkg/include"],
      [f.dirname for f in hdrs])
  inputs = hdrs + go.stdlib.files + [source]

  asm_args = go.args(go)
  asm_args.add(["-o", out_obj, "-trimpath", "."])
  asm_args.add(includes, before_each="-I")
  asm_args.add(source.path)
  go.actions.run(
      inputs = inputs,
      outputs = [out_obj],
      mnemonic = "GoAsmCompile",
      executable = go.builders.asm,
      arguments = [asm_args],
  )
  return out_obj
