# Copyright 2018 The Bazel Go Rules Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:providers.bzl", "GoBuilders")

def _builders_impl(ctx):
    return [
        GoBuilders(
            nogo_generator = ctx.executable._nogo_generator,
        ),
        DefaultInfo(
            files = depset([
                ctx.executable._nogo_generator,
            ]),
        ),
    ]

builders = rule(
    _builders_impl,
    attrs = {
        "_nogo_generator": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:generate_nogo_main",
        ),
    },
)
