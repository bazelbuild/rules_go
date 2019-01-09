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
            compile = ctx.executable._compile,
            link = ctx.executable._link,
            cgo = ctx.executable._cgo,
            nogo_generator = ctx.executable._nogo_generator,
            test_generator = ctx.executable._test_generator,
        ),
        DefaultInfo(
            files = depset([
                ctx.executable._compile,
                ctx.executable._link,
                ctx.executable._cgo,
                ctx.executable._nogo_generator,
                ctx.executable._test_generator,
            ]),
        ),
    ]

builders = rule(
    _builders_impl,
    attrs = {
        "_compile": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:compile",
        ),
        "_link": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:link",
        ),
        "_cgo": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:cgo",
        ),
        "_nogo_generator": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:generate_nogo_main",
        ),
        "_test_generator": attr.label(
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:generate_test_main",
        ),
    },
)
