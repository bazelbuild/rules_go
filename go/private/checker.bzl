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

load("@io_bazel_rules_go//go/private:common.bzl", "env_execute")

def _go_register_checker_impl(ctx):
  ctx.template("BUILD.bazel",
      Label("@io_bazel_rules_go//go/private:BUILD.checker.bazel"),
      substitutions = {
        "{{checker}}": ctx.attr.checker,
      },
      executable = False,
  )

go_register_checker = repository_rule(
    _go_register_checker_impl,
    attrs = {
        "checker": attr.string(mandatory = True),
    },
)
