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

load("@io_bazel_rules_go//go/private:actions/action.bzl",
    "action_with_go_env",
)

def emit_asm(ctx, go_toolchain,
    source = None,
    hdrs = [],
    out_obj = None):
  """See go/toolchains.rst#asm for full documentation."""

  if source == None: fail("source is a required parameter")
  if out_obj == None: fail("out_obj is a required parameter")
  includes = depset()
  includes += [f.dirname for f in hdrs]
  includes += [f.dirname for f in go_toolchain.data.headers.cc.transitive_headers]
  inputs = hdrs + list(go_toolchain.data.headers.cc.transitive_headers) + [source]
  asm_args = [source.path, "-o", out_obj.path]
  for inc in includes:
    asm_args += ["-I", inc]
  action_with_go_env(ctx, go_toolchain,
      inputs = list(inputs),
      outputs = [out_obj],
      mnemonic = "GoAsmCompile",
      executable = go_toolchain.tools.asm,
      arguments = asm_args,
  )
