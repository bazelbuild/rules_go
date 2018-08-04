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

load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoStdLib",
)
load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_C_ARCHIVE",
    "LINKMODE_C_SHARED",
    "LINKMODE_NORMAL",
    "LINKMODE_PLUGIN",
)

def _stdlib_library_to_source(go, attr, source, merge):
    if _should_use_sdk_stdlib(go):
        source["stdlib"] = _sdk_stdlib(go)
    else:
        source["stdlib"] = _build_stdlib(go, attr)

def _should_use_sdk_stdlib(go):
    return (go.mode.goos == go.sdk.goos and
            go.mode.goarch == go.sdk.goarch and
            not go.mode.race and  # TODO(jayconrod): use precompiled race
            not go.mode.msan and
            not go.mode.pure and
            go.mode.link == LINKMODE_NORMAL)

def _sdk_stdlib(go):
    return GoStdLib(
        root_file = go.sdk.root_file,
        libs = go.sdk.libs,
    )

def _build_stdlib(go, attr):
    pkg = go.declare_directory(go, "pkg")
    src = go.declare_directory(go, "src")
    root_file = go.declare_file(go, "ROOT")
    filter_buildid = attr._filter_buildid_builder.files.to_list()[0]
    args = go.args(go)
    args.add_all(["-out", root_file.dirname])
    if go.mode.race:
        args.add("-race")
    if go.mode.link in [LINKMODE_C_ARCHIVE, LINKMODE_C_SHARED]:
        args.add("-shared")
    if go.mode.link == LINKMODE_PLUGIN:
        args.add("-dynlink")
    args.add_all(["-filter_buildid", filter_buildid])
    go.actions.write(root_file, "")
    env = go.env
    env.update({
        "CC": go.cgo_tools.compiler_executable,
        "CGO_CPPFLAGS": " ".join(go.cgo_tools.compiler_options),
        "CGO_CFLAGS": " ".join(go.cgo_tools.c_options),
        "CGO_LDFLAGS": " ".join(go.cgo_tools.linker_options),
    })
    inputs = (go.sdk.srcs +
              go.sdk.headers +
              go.sdk.tools +
              [go.sdk.go, filter_buildid, go.sdk.package_list, go.sdk.root_file] +
              go.crosstool)
    outputs = [pkg, src]
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoStdlib",
        executable = attr._stdlib_builder.files.to_list()[0],
        arguments = [args],
        env = env,
    )
    return GoStdLib(
        root_file = root_file,
        libs = [pkg],
    )

def _stdlib_impl(ctx):
    go = go_context(ctx)
    library = go.new_library(go, resolver = _stdlib_library_to_source)
    source = go.library_to_source(go, ctx.attr, library, False)
    return [source, library]

stdlib = go_rule(
    _stdlib_impl,
    bootstrap = True,
    attrs = {
        "_stdlib_builder": attr.label(
            executable = True,
            cfg = "host",
            default = "@io_bazel_rules_go//go/tools/builders:stdlib",
        ),
        "_filter_buildid_builder": attr.label(
            executable = True,
            cfg = "host",
            default = "@io_bazel_rules_go//go/tools/builders:filter_buildid",
        ),
    },
)
