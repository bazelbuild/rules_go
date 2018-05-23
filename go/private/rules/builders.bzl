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
            asm = ctx.executable._asm,
            compile = ctx.executable._compile,
            pack = ctx.executable._pack,
            link = ctx.executable._link,
            cgo = ctx.executable._cgo,
            test_generator = ctx.executable._test_generator,
            cover = ctx.executable._cover,
        ),
        DefaultInfo(
            files = depset([
                ctx.executable._asm,
                ctx.executable._compile,
                ctx.executable._pack,
                ctx.executable._link,
                ctx.executable._cgo,
                ctx.executable._test_generator,
                ctx.executable._cover,
            ]),
        ),
    ]

builders = rule(
    _builders_impl,
    attrs = {
        "_asm": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:asm",
        ),
        "_compile": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:compile",
        ),
        "_pack": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:pack",
        ),
        "_link": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:link",
        ),
        "_cgo": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:cgo",
        ),
        "_test_generator": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:generate_test_main",
        ),
        "_cover": attr.label(
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
            default = "//go/tools/builders:cover",
        ),
    },
)
