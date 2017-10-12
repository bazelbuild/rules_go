# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoStdLib",
)

def _stdlib_impl(ctx):
  return [
      DefaultInfo(
          files = depset(ctx.files.libs),
      ),
      GoStdLib(
          root_file = ctx.file._root_file,
          goos = ctx.attr.goos,
          goarch = ctx.attr.goarch,
          libs = ctx.files.libs,
          cgo = ctx.attr.cgo,
      ),
  ]

stdlib = rule(
    _stdlib_impl,
    attrs = {
        "goos": attr.string(mandatory = True),
        "goarch": attr.string(mandatory = True),
        "cgo": attr.bool(mandatory = True),
        "libs": attr.label_list(allow_files = True),
        "_root_file": attr.label(allow_files = True, single_file = True, default="@go_sdk//:root_file"),
    },
)
