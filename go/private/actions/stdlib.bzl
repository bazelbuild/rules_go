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
    "//go/private:common.bzl",
    "COVERAGE_OPTIONS_DENYLIST",
)
load(
    "//go/private:providers.bzl",
    "GoStdLib",
)
load(
    "//go/private:mode.bzl",
    "LINKMODE_NORMAL",
    "extldflags_from_cc_toolchain",
    "link_mode_args",
)
load("//go/private:sdk.bzl", "parse_version")
load("//go/private/actions:utils.bzl", "quote_opts")

def emit_stdlib(go):
    """Returns a standard library for the target configuration.

    If the precompiled standard library is suitable, it will be returned.
    Otherwise, the standard library will be compiled for the target.

    Returns:
        A list of providers containing GoLibrary and GoSource. GoSource.stdlib
        will point to a new GoStdLib.
    """
    library = go.new_library(go, resolver = _stdlib_library_to_source)
    source = go.library_to_source(go, {}, library, False)
    return [source, library]

def _stdlib_library_to_source(go, _attr, source, _merge):
    if _should_use_sdk_stdlib(go):
        source["stdlib"] = _sdk_stdlib(go)
    else:
        source["stdlib"] = _build_stdlib(go)

def _should_use_sdk_stdlib(go):
    version = parse_version(go.sdk.version)
    if version and version[0] <= 1 and version[1] <= 19 and go.sdk.experiments:
        # The precompiled stdlib shipped with 1.19 or below doesn't have experiments
        return False
    return (go.sdk.libs and  # go.sdk.libs is non-empty if sdk ships with precompiled .a files
            go.mode.goos == go.sdk.goos and
            go.mode.goarch == go.sdk.goarch and
            not go.mode.race and  # TODO(jayconrod): use precompiled race
            not go.mode.msan and
            not go.mode.pure and
            not go.mode.gc_goopts and
            go.mode.link == LINKMODE_NORMAL)

def _build_stdlib_list_json(go):
    out = go.declare_file(go, "stdlib.pkg.json")
    args = go.builder_args(go, "stdliblist")
    args.add("-sdk", go.sdk.root_file.dirname)
    args.add("-out", out)
    go.actions.run(
        inputs = go.sdk_files,
        outputs = [out],
        mnemonic = "GoStdlibList",
        executable = go.toolchain._builder,
        arguments = [args],
        env = go.env,
    )
    return out

def _sdk_stdlib(go):
    return GoStdLib(
        _list_json = _build_stdlib_list_json(go),
        libs = go.sdk.libs,
        root_file = go.sdk.root_file,
    )

def _build_stdlib(go):
    pkg = go.declare_directory(go, path = "pkg")
    args = go.builder_args(go, "stdlib")
    args.add("-out", pkg.dirname)
    if go.mode.race:
        args.add("-race")
    args.add_all(go.sdk.experiments, before_each = "-experiment")
    args.add("-package", "std")
    if not go.mode.pure:
        args.add("-package", "runtime/cgo")
    args.add_all(link_mode_args(go.mode))
    env = go.env
    if go.mode.pure:
        env.update({"CGO_ENABLED": "0"})
    else:
        # NOTE(#2545): avoid unnecessary dynamic link
        # go std library doesn't use C++, so should not have -lstdc++
        # Also drop coverage flags as nothing in the stdlib is compiled with
        # coverage - we disable it for all CGo code anyway.
        ldflags = [
            option
            for option in extldflags_from_cc_toolchain(go)
            if option not in ("-lstdc++", "-lc++") and option not in COVERAGE_OPTIONS_DENYLIST
        ]
        env.update({
            "CGO_ENABLED": "1",
            "CC": go.cgo_tools.c_compiler_path,
            "CGO_CFLAGS": " ".join(go.cgo_tools.c_compile_options),
            "CGO_LDFLAGS": " ".join(ldflags),
        })
    args.add("-gcflags", quote_opts(go.mode.gc_goopts))
    inputs = (go.sdk.srcs +
              go.sdk.headers +
              go.sdk.tools +
              [go.sdk.go, go.sdk.package_list, go.sdk.root_file] +
              go.crosstool)
    outputs = [pkg]
    go.actions.run(
        inputs = inputs,
        outputs = outputs,
        mnemonic = "GoStdlib",
        executable = go.toolchain._builder,
        arguments = [args],
        env = env,
    )
    return GoStdLib(
        _list_json = _build_stdlib_list_json(go),
        libs = [pkg],
        root_file = pkg,
    )
