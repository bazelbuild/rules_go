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

load("@io_bazel_rules_go//go/private:providers.bzl", "GoPath")

def _go_fmt_generate_impl(ctx):
  print("""
EXPERIMENTAL: the go_fmt_test rule is still very experimental
Please do not rely on it for production use, but feel free to use it and file issues
""")
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  stdlib = go_toolchain.stdlib.get(ctx, go_toolchain)
  script_file = ctx.new_file(ctx.label.name+".bash")
  files = ctx.files.data + stdlib.files
  packages = []
  content="""
STATUS=0
"""
  for data in ctx.attr.data:
    entry = data[GoPath]
    for package in entry.packages:
      content += """
if [[ $({gofmt} -d -e {package}/*.go | tee /dev/stderr) ]]; then STATUS=1; fi
""".format(
      gofmt=stdlib.gofmt.short_path,
      package=package.dir,
    )
  content += """
exit $STATUS
"""
  ctx.file_action(output=script_file, executable=True, content=content)
  return struct(
    files = depset([script_file]),
    runfiles = ctx.runfiles(files, collect_data = True),
  )

_go_fmt_generate = rule(
    _go_fmt_generate_impl,
    attrs = {
        "data": attr.label_list(providers=[GoPath], cfg = "data"),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def go_fmt_test(name, data, **kwargs):
  script_name = "generate_"+name
  _go_fmt_generate(
    name=script_name,
    data=data,
    tags = ["manual"],
  )
  native.sh_test(
    name=name,
    srcs=[script_name],
    data=data,
    **kwargs
  )