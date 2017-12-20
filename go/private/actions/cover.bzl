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
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoSource",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "structs",
)

def emit_cover(go, source):
  """See go/toolchains.rst#cover for full documentation."""

  if source == None: fail("source is a required parameter")
  if not source.cover:
    return source, []

  covered = []
  cover_vars = []
  for src in source.srcs:
    if not src.basename.endswith(".go") or src not in source.cover:
      covered.append(src)
      continue
    cover_var = "Cover_" + src.basename[:-3].replace("-", "_").replace(".", "_")
    cover_vars.append("{}={}={}".format(cover_var, src.short_path, source.library.importpath))
    out = go.declare_file(go, path=cover_var, ext='.cover.go')
    covered.append(out)
    args = go.args(go)
    args.add(["--", "--mode=set", "-var=%s" % cover_var, "-o", out, src])
    go.actions.run(
        inputs = [src] + go.stdlib.files,
        outputs = [out],
        mnemonic = "GoCover",
        executable = go.toolchain.tools.cover,
        arguments = [args],
    )
  members = structs.to_dict(source)
  members["srcs"] = covered
  return GoSource(**members), cover_vars
