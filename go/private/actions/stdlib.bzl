# Copyright 2019 The Bazel Go Rules Authors. All rights reserved.
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
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_NORMAL",
    "extldflags_from_cc_toolchain",
    "link_mode_args",
    "mode_string",
)

def emit_stdlib(go):
    """emit_stdlib builds the standard library for the target configuration
    or uses the precompiled standard library if it is suitable.

    Returns:
        A list of providers containing GoLibrary and GoSource. GoSource.stdlib
        will point to a new GoStdLib.
    """
    library = go.new_library(go, resolver = _stdlib_library_to_source)
    source = go.library_to_source(go, {}, library, False)
    return [source, library]

def _stdlib_library_to_source(go, attr, source, merge):
    if _should_use_sdk_stdlib(go):
        source["stdlib"] = _sdk_stdlib(go)
    else:
        source["stdlib"] = _build_stdlib(go)

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

def _build_stdlib(go):
    pkg = go.declare_directory(go, "pkg")
    src = go.declare_directory(go, "src")
    root_file = go.declare_file(go, "ROOT")
    args = go.builder_args(go, "stdlib")
    args.add("-out", root_file.dirname)
    if go.mode.race:
        args.add("-race")
    args.add_all(link_mode_args(go.mode))
    go.actions.write(root_file, "")
    env = go.env
    if go.mode.pure:
        env.update({"CGO_ENABLED": "0"})
    else:
        env.update({
            "CGO_ENABLED": "1",
            "CC": go.cgo_tools.c_compiler_path,
            "CGO_CFLAGS": " ".join(go.cgo_tools.c_compile_options),
            "CGO_LDFLAGS": " ".join(extldflags_from_cc_toolchain(go)),
        })
    inputs = (go.sdk.srcs +
              go.sdk.headers +
              go.sdk.tools +
              [go.sdk.go, go.sdk.package_list, go.sdk.root_file] +
              go.crosstool)
    outputs = [pkg, src]
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoStdlib",
        executable = go.toolchain._builder,
        arguments = [args],
        env = env,
    )
    return GoStdLib(
        root_file = root_file,
        libs = [pkg],
    )
