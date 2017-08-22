# Copyright 2017 The Bazel Authors. All rights reserved.
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

def _go_embed_data_impl(ctx):
  if ctx.attr.src and ctx.attr.srcs:
    fail("%s: src and srcs attributes cannot both be specified" % ctx.label)
  if ctx.attr.src and ctx.attr.flatten:
    fail("%s: src and flatten attributes cannot both be specified" % ctx.label)

  if ctx.attr.src:
    srcs = [ctx.file.src]
    args = []
  else:
    srcs = ctx.files.srcs
    args = ["-multi"]

  if ctx.attr.package:
    package = ctx.attr.package
  else:
    _, _, package = ctx.label.package.rpartition("/")
    if package == "":
      fail("%s: must provide package attribute for go_embed_data rules in the repository root directory" % ctx.label)

  args += [
    "-workspace", ctx.workspace_name,
    "-label", str(ctx.label),
    "-out", ctx.outputs.out.path,
    "-package", package,
    "-var", ctx.attr.var,
  ]
  if ctx.attr.flatten:
    args += ["-flatten"]
  if ctx.attr.string:
    args += ["-string"]
  args += [f.path for f in srcs]

  ctx.action(
      outputs = [ctx.outputs.out],
      inputs = srcs,
      executable = ctx.executable._embed,
      arguments = args,
      mnemonic = "GoEmbedData",
  )

go_embed_data = rule(
    implementation = _go_embed_data_impl,
    attrs = {
        "out": attr.output(mandatory = True),
        "package": attr.string(),
        "var": attr.string(default = "Data"),
        "src": attr.label(allow_single_file = True),
        "srcs": attr.label_list(allow_files = True),
        "flatten": attr.bool(),
        "string": attr.bool(),
        "_embed": attr.label(
            default = Label("@io_bazel_rules_go//go/tools/builders:embed"),
            executable = True,
            cfg = "host",
        ),
    },
)
"""go_embed_data generates a .go file that contains data from a file or a
list of files.

go_embed_data has the following attributes:
    out: File name of the .go file to generate.
    package: Go package name for the generated .go file.
    var: Name of the variable that will contain the embedded data.
    src: A single file to embed. This cannot be used at the same time as srcs.
        The generated file will have a variable of type []byte or string with
        the contents of this file.
    srcs: A list of files to embed. This cannot be used at the same time as
        src. The generated file will have a variable of type map[string][]byte
        or map[string]string with the contents of each file. The map keys are
        relative paths the files from the repository root. Keys for files in
        external repositories will be prefixed with "external/repo/" where
        "repo" is the name of the external repository.
    flatten: If true and srcs is used, map keys are file base names instead
        of relative paths.
    string: If true, the embedded data will be stored as string instead
        of []byte.
"""
