# Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
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
    "GoArchive",
    "GoStdLib",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

GoPkgInfo = provider()

DEPS_ATTRS = [
    "deps",
    "embed",
]

PROTO_COMPILER_ATTRS = [
    "compiler",
    "compilers",
]

def bazel_supports_canonical_label_literals():
    return str(Label("//:bogus")).startswith("@@")

def is_file_external(f):
    return f.owner.workspace_root != ""

def file_path(f):
    prefix = "__BAZEL_WORKSPACE__"
    if not f.is_source:
        prefix = "__BAZEL_EXECROOT__"
    elif is_file_external(f):
        prefix = "__BAZEL_OUTPUT_BASE__"
    return paths.join(prefix, f.path)

def _go_archive_to_pkg(archive):
    return struct(
        ID = str(archive.data.label),
        PkgPath = archive.data.importpath,
        ExportFile = file_path(archive.data.export_file),
        GoFiles = [
            file_path(src)
            for src in archive.data.orig_srcs
            if src.path.endswith(".go")
        ],
        CompiledGoFiles = [
            file_path(src)
            for src in archive.data.srcs
            if src.path.endswith(".go")
        ],
        OtherFiles = [
            file_path(src)
            for src in archive.data.orig_srcs
            if not src.path.endswith(".go")
        ],
    )

def make_pkg_json(ctx, name, pkg_info):
    pkg_json_file = ctx.actions.declare_file(name + ".pkg.json")
    ctx.actions.write(pkg_json_file, content = pkg_info.to_json())
    return pkg_json_file

def _go_pkg_info_aspect_impl(target, ctx):
    # Fetch the stdlib JSON file from the inner most target
    stdlib_json_file = None

    transitive_json_files = []
    transitive_export_files = []
    transitive_compiled_go_files = []

    for attr in DEPS_ATTRS + PROTO_COMPILER_ATTRS:
        for dep in getattr(ctx.rule.attr, attr, []) or []:
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                transitive_json_files.append(pkg_info.pkg_json_files)
                transitive_compiled_go_files.append(pkg_info.compiled_go_files)
                transitive_export_files.append(pkg_info.export_files)

                # Fetch the stdlib json from the first dependency
                if not stdlib_json_file:
                    stdlib_json_file = pkg_info.stdlib_json_file

    pkg_json_files = []
    compiled_go_files = []
    export_files = []

    if GoArchive in target:
        archive = target[GoArchive]
        compiled_go_files.extend(archive.source.srcs)
        export_files.append(archive.data.export_file)
        pkg = _go_archive_to_pkg(archive)
        pkg_json_files.append(make_pkg_json(ctx, archive.data.name, pkg))

        if ctx.rule.kind == "go_test":
            for dep_archive in archive.direct:
                # find the archive containing the test sources
                if archive.data.label == dep_archive.data.label:
                    pkg = _go_archive_to_pkg(dep_archive)
                    pkg_json_files.append(make_pkg_json(ctx, dep_archive.data.name, pkg))
                    compiled_go_files.extend(dep_archive.source.srcs)
                    export_files.append(dep_archive.data.export_file)
                    break

    # If there was no stdlib json in any dependencies, fetch it from the
    # current go_ node.
    if not stdlib_json_file:
        stdlib_json_file = ctx.attr._go_stdlib[GoStdLib]._list_json

    pkg_info = GoPkgInfo(
        stdlib_json_file = stdlib_json_file,
        pkg_json_files = depset(
            direct = pkg_json_files,
            transitive = transitive_json_files,
        ),
        compiled_go_files = depset(
            direct = compiled_go_files,
            transitive = transitive_compiled_go_files,
        ),
        export_files = depset(
            direct = export_files,
            transitive = transitive_export_files,
        ),
    )

    return [
        pkg_info,
        OutputGroupInfo(
            go_pkg_driver_json_file = pkg_info.pkg_json_files,
            go_pkg_driver_srcs = pkg_info.compiled_go_files,
            go_pkg_driver_export_file = pkg_info.export_files,
            go_pkg_driver_stdlib_json_file = depset([pkg_info.stdlib_json_file] if pkg_info.stdlib_json_file else []),
        ),
    ]

go_pkg_info_aspect = aspect(
    implementation = _go_pkg_info_aspect_impl,
    attr_aspects = DEPS_ATTRS + PROTO_COMPILER_ATTRS,
    attrs = {
        "_go_stdlib": attr.label(
            default = "//:stdlib",
        ),
    },
)
