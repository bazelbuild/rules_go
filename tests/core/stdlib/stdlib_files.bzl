# Copyright 2018 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:providers.bzl", "GoSource")

def _stdlib_files_impl(ctx):
  files = ctx.attr._stdlib[GoSource].stdlib.files
  runfiles = ctx.runfiles(files = files)
  return [DefaultInfo(
      files = depset(files),
      runfiles = runfiles,
  )]

stdlib_files = rule(
    _stdlib_files_impl,
    attrs = {
        "_stdlib": attr.label(default = "@io_bazel_rules_go//:stdlib"),
    },
)
