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

DEFAULT_NOGO = "@io_bazel_rules_go//:default_nogo"

def _go_register_nogo_impl(ctx):
    ctx.template(
        "BUILD.bazel",
        Label("//go/private:BUILD.nogo.bazel"),
        substitutions = {
            "{{nogo}}": ctx.attr.nogo,
        },
        executable = False,
    )

# go_register_nogo creates a repository with an alias that points
# to the nogo rule that should be used globally by go rules in the workspace.
# This may be called automatically by go_rules_dependencies or by
# go_register_toolchains.
go_register_nogo = repository_rule(
    _go_register_nogo_impl,
    attrs = {
        "nogo": attr.string(mandatory = True),
    },
)
