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

load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

def _go_info_impl(ctx):
    go = go_context(ctx)
    report = go.declare_file(go, "go_info_report")
    args = go.builder_args(go)
    args.add("-out", report)
    go.actions.run(
        inputs = go.sdk_files,
        outputs = [report],
        mnemonic = "GoInfo",
        executable = ctx.executable._go_info,
        arguments = [args],
    )
    return [DefaultInfo(
        files = depset([report]),
        runfiles = ctx.runfiles([report]),
    )]

_go_info = go_rule(
    _go_info_impl,
    attrs = {
        "_go_info": attr.label(
            executable = True,
            cfg = "host",
            default = "@io_bazel_rules_go//go/tools/builders:info",
        ),
    },
)

def go_info():
    _go_info(
        name = "go_info",
        visibility = ["//visibility:public"],
    )
