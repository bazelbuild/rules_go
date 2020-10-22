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
    "//go/private:providers.bzl",
    "GoSource",
    "effective_importpath_pkgpath",
)
load(
    "@bazel_skylib//lib:structs.bzl",
    "structs",
)

def _sanitize(s):
    """Replaces /, -, and . with _."""
    return s.replace("/", "_").replace("-", "_").replace(".", "_")

def emit_cover(go, source):
    """See go/toolchains.rst#cover for full documentation."""

    if source == None:
        fail("source is a required parameter")
    if not source.cover:
        return source

    covered = []
    covered_src_map = dict(source.orig_src_map)
    for src in source.srcs:
        if not src.basename.endswith(".go") or src not in source.cover:
            covered.append(src)
            continue
        orig = covered_src_map.get(src, src)
        _, pkgpath = effective_importpath_pkgpath(source.library)
        srcname = pkgpath + "/" + orig.basename if pkgpath else orig.path

        cover_var = "Cover_%s_%s" % (_sanitize(pkgpath), _sanitize(src.basename[:-3]))
        out = go.declare_file(go, path = "Cover_%s" % _sanitize(src.basename[:-3]), ext = ".cover.go")
        covered_src_map.pop(src, None)
        covered_src_map[out] = orig
        covered.append(out)

        args = go.builder_args(go, "cover")
        args.add("-o", out)
        args.add("-var", cover_var)
        args.add("-src", src)
        args.add("-srcname", srcname)

        if go.mode.race:
            args.add("-mode", "atomic")
        else:
            args.add("-mode", "set")
        go.actions.run(
            inputs = [src] + go.sdk.tools,
            outputs = [out],
            mnemonic = "GoCover",
            executable = go.toolchain._builder,
            arguments = [args],
            env = go.env,
        )
    members = structs.to_dict(source)
    members["srcs"] = covered
    members["orig_src_map"] = covered_src_map
    return GoSource(**members)
