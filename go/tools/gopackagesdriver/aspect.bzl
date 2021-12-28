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

def _go_archive_to_pkg(archive):
    return struct(
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

def _make_pkg_json(ctx, archive, pkg_info):
    pkg_json_file = ctx.actions.declare_file(archive.data.name + ".pkg.json")
    ctx.actions.write(pkg_json_file, content = pkg_info.to_json())
    return pkg_json_file

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

    pkg_json_files = []
    compiled_go_files = []
    export_files = []

    if GoArchive in target:
        archive = target[GoArchive]
        compiled_go_files.extend(archive.source.srcs)
        export_files.append(archive.data.export_file)
        pkg = _go_archive_to_pkg(archive)
        pkg_json_files.append(_make_pkg_json(ctx, archive, pkg))

        # if the rule is a test, we need to get the embedded go_library with the current
        # test's sources. For that, consume the dependency via GoArchive.direct so that
        # the test source files are there. Then, create the pkg json file directly. Only
        # do that for direct dependencies that are not defined as deps, and use the
        # importpath to find which.
        if ctx.rule.kind == "go_test":
            deps_targets = [
                dep[GoArchive].data.importpath
                for dep in ctx.rule.attr.deps
                if GoArchive in dep
            ]
            for archive in target[GoArchive].direct:
                if archive.data.importpath not in deps_targets:
                    pkg = _go_archive_to_pkg(archive)
                    pkg_json_files.append(_make_pkg_json(ctx, archive, pkg))
                    compiled_go_files.extend(archive.source.srcs)
                    export_files.append(archive.data.export_file)

    # If there was no stdlib json in any dependencies, fetch it from the
    # current go_ node.
    if not stdlib_json_file:
        stdlib_json_file = ctx.attr._go_stdlib[GoStdLib]._list_json

    pkg_info = GoPkgInfo(
        stdlib_json_file = stdlib_json_file,
        transitive_json_file = depset(
            direct = pkg_json_files,
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
            direct = export_files,
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
            default = "//:stdlib",
        ),
    },
)
