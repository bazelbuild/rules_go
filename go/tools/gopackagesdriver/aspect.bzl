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

def _is_file_external(f):
    return f.owner.workspace_root != ""

def _file_path(f):
    prefix = "__BAZEL_WORKSPACE__"
    if not f.is_source:
        prefix = "__BAZEL_EXECROOT__"
    elif _is_file_external(f):
        prefix = "__BAZEL_OUTPUT_BASE__"
    return paths.join(prefix, f.path)

def _new_pkg_info(archive_data):
    return struct(
        ID = str(archive_data.label),
        PkgPath = archive_data.importpath,
        ExportFile = _file_path(archive_data.export_file),
        GoFiles = [
            _file_path(src)
            for src in archive_data.orig_srcs
        ],
        CompiledGoFiles = [
            _file_path(src)
            for src in archive_data.srcs
        ],
    )

def _go_pkg_info_aspect_impl(target, ctx):
    # Fetch the stdlib JSON file from the inner most target
    stdlib_json_file = None

    deps_transitive_json_file = []
    deps_transitive_export_file = []
    deps_transitive_compiled_go_files = []
    for attr in ["deps", "embed"]:
        for dep in getattr(ctx.rule.attr, attr, []):
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                if attr == "deps":
                    deps_transitive_json_file.append(pkg_info.transitive_json_file)
                    deps_transitive_export_file.append(pkg_info.transitive_export_file)
                    deps_transitive_compiled_go_files.append(pkg_info.transitive_compiled_go_files)
                elif attr == "embed":
                    # If deps are embedded, do not gather their json or export_file since they
                    # are included in the current target, but do gather their deps'.
                    deps_transitive_json_file.append(pkg_info.deps_transitive_json_file)
                    deps_transitive_export_file.append(pkg_info.deps_transitive_export_file)
                    deps_transitive_compiled_go_files.append(pkg_info.deps_transitive_compiled_go_files)

                # Fetch the stdlib json from the first dependency
                if not stdlib_json_file:
                    stdlib_json_file = pkg_info.stdlib_json_file

    pkg_json_file = None
    compiled_go_files = []
    export_file = None
    if GoArchive in target:
        archive = target[GoArchive]
        compiled_go_files = archive.data.srcs
        export_file = archive.data.export_file
        pkg = struct(
            ID = str(archive.data.label),
            PkgPath = archive.data.importpath,
            ExportFile = _file_path(archive.data.export_file),
            GoFiles = [
                _file_path(src)
                for src in archive.data.orig_srcs
            ],
            CompiledGoFiles = [
                _file_path(src)
                for src in archive.data.srcs
            ],
        )
        pkg_json_file = ctx.actions.declare_file(archive.data.name + ".pkg.json")
        ctx.actions.write(pkg_json_file, content = pkg.to_json())

    # If there was no stdlib json in any dependencies, fetch it from the
    # current go_ node.
    if not stdlib_json_file:
        stdlib_json_file = ctx.attr._go_stdlib[GoStdLib]._list_json

    pkg_info = GoPkgInfo(
        json = pkg_json_file,
        stdlib_json_file = stdlib_json_file,
        transitive_json_file = depset(
            direct = [pkg_json_file] if pkg_json_file else [],
            transitive = deps_transitive_json_file,
        ),
        deps_transitive_json_file = depset(
            transitive = deps_transitive_json_file,
        ),
        transitive_compiled_go_files = depset(
            direct = compiled_go_files,
            transitive = deps_transitive_compiled_go_files,
        ),
        deps_transitive_compiled_go_files = depset(
            transitive = deps_transitive_compiled_go_files,
        ),
        transitive_export_file = depset(
            direct = [export_file] if export_file else [],
            transitive = deps_transitive_export_file,
        ),
        deps_transitive_export_file = depset(
            transitive = deps_transitive_export_file,
        ),
    )

    return [
        pkg_info,
        OutputGroupInfo(
            go_pkg_driver_json_file = pkg_info.transitive_json_file,
            go_pkg_driver_srcs = pkg_info.transitive_compiled_go_files,
            go_pkg_driver_export_file = pkg_info.transitive_export_file,
            go_pkg_driver_stdlib_json_file = depset([pkg_info.stdlib_json_file] if pkg_info.stdlib_json_file else []),
        ),
    ]

go_pkg_info_aspect = aspect(
    implementation = _go_pkg_info_aspect_impl,
    attr_aspects = ["embed", "deps"],
    attrs = {
        "_go_stdlib": attr.label(
            default = "@io_bazel_rules_go//:stdlib",
        ),
    },
)
