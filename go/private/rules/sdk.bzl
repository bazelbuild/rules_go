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
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoSDK",
)

def _go_sdk_impl(ctx):
    return [GoSDK(
        goos = ctx.attr.goos,
        goarch = ctx.attr.goarch,
        root_file = ctx.file.root_file,
        package_list = ctx.file.package_list,
        libs = ctx.files.libs,
        headers = ctx.files.headers,
        srcs = ctx.files.srcs,
        tools = ctx.files.tools,
        go = ctx.file.go,
    )]

go_sdk = rule(
    _go_sdk_impl,
    attrs = {
        "goos": attr.string(
            mandatory = True,
            doc = "The host OS the SDK was built for",
        ),
        "goarch": attr.string(
            mandatory = True,
            doc = "The host architecture the SDK was built for",
        ),
        "root_file": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "A file in the SDK root directory. Used to determine GOROOT.",
        ),
        "package_list": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = ("A text file containing a list of packages in the " +
                   "standard library that may be imported."),
        ),
        "libs": attr.label_list(
            allow_files = [".a"],
            doc = ("Pre-compiled .a files for the standard library, " +
                   "built for the execution platform"),
        ),
        "headers": attr.label_list(
            allow_files = [".h"],
            doc = (".h files from pkg/include that may be included in " +
                   "assembly sources"),
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Source files for packages in the standard library",
        ),
        "tools": attr.label_list(
            allow_files = True,
            cfg = "host",
            doc = ("List of executable files from pkg/tool " +
                   "built for the execution platform"),
        ),
        "go": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "host",
            doc = "The go binary",
        ),
    },
    doc = ("Collects information about a Go SDK. The SDK must have a normal " +
           "GOROOT directory structure."),
    provides = [GoSDK],
)

def _package_list_impl(ctx):
    packages = {}
    src_dir = ctx.file.root_file.dirname + "/src/"
    for src in ctx.files.srcs:
        pkg_src_dir = src.dirname
        if not pkg_src_dir.startswith(src_dir):
            continue
        pkg_name = pkg_src_dir[len(src_dir):]
        if any([prefix in pkg_name for prefix in ("vendor/", "cmd/")]):
            continue
        packages[pkg_name] = None
    content = "\n".join(sorted(packages.keys())) + "\n"
    ctx.actions.write(ctx.outputs.out, content)
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

package_list = rule(
    _package_list_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Source files for packages in the standard library",
        ),
        "root_file": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "A file in the SDK root directory. Used to determine GOROOT.",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "File to write. Must be 'packages.txt'.",
            # Gazelle depends on this file directly. It has to be an output
            # attribute because Bazel has no other way of knowing what rule
            # produces this file.
            # TODO(jayconrod): Update Gazelle and simplify this.
        ),
    },
)
