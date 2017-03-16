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

def go_tool_binary(name, srcs):
  """Builds a Go program using `go build`.

  This is used instead of `go_binary` for tools that are executed inside
  actions emitted by the go rules. This avoids a bootstrapping problem. This
  is very limited and only supports sources in the main package with no
  dependencies outside the standard library.

  Args:
    name: A unique name for this rule.
    srcs: list of pure Go source files. No cgo allowed.
  """
  native.genrule(
      name = name,
      srcs = srcs + ["//go/toolchain:go_src"],
      outs = [name + "_bin"],
      cmd = " ".join([
          "GOROOT=$$(cd $$(dirname $(location //go/toolchain:go_tool))/..; pwd)",
          "$(location //go/toolchain:go_tool)",
          "build",
          "-o",
          "$@",
          "$(locations %s)" % " ".join(srcs),
      ]),
      executable = True,
      tools = [
        "//go/toolchain",
        "//go/toolchain:go_tool",
      ],
      visibility = ["//visibility:public"],
  )
