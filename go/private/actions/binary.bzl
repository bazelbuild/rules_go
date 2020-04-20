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
    "//go/private:mode.bzl",
    "LINKMODE_C_ARCHIVE",
    "LINKMODE_C_SHARED",
    "LINKMODE_PLUGIN",
)
load(
    "//go/private:common.bzl",
    "ARCHIVE_EXTENSION",
    "has_shared_lib_extension",
)

def new_cc_import(go,
        hdrs = None,
        defines = None,
        local_defines = None,
        dynamic_library = None,
        static_library = None,
        alwayslink = False,
        linkopts = None,
    ):
    return CcInfo(
        compilation_context = cc_common.create_compilation_context(
            defines = defines or depset([]),
            local_defines = local_defines or depset([]),
            headers = hdrs or depset([]),
            includes = depset([hdr.root.path for hdr in hdrs.to_list()]),
        ),
        linking_context = cc_common.create_linking_context(
            libraries_to_link = [cc_common.create_library_to_link(
                actions = go._ctx.actions,
                cc_toolchain = go.cgo_tools.cc_toolchain,
                feature_configuration = go.cgo_tools.feature_configuration,
                dynamic_library = dynamic_library,
                static_library = static_library,
                alwayslink = alwayslink,
            )],
            user_link_flags = linkopts,
        ),
    )

def emit_binary(
        go,
        name = "",
        source = None,
        test_archives = [],
        gc_linkopts = [],
        version_file = None,
        info_file = None,
        executable = None):
    """See go/toolchains.rst#binary for full documentation."""

    if name == "" and executable == None:
        fail("either name or executable must be set")

    archive = go.archive(go, source)
    if not executable:
        extension = go.exe_extension
        if go.mode.link == LINKMODE_C_SHARED:
            name = "lib" + name  # shared libraries need a "lib" prefix in their name
            extension = go.shared_extension
        elif go.mode.link == LINKMODE_C_ARCHIVE:
            extension = ARCHIVE_EXTENSION
        elif go.mode.link == LINKMODE_PLUGIN:
            extension = go.shared_extension
        executable = go.declare_file(go, path = name, ext = extension)
    go.link(
        go,
        archive = archive,
        test_archives = test_archives,
        executable = executable,
        gc_linkopts = gc_linkopts,
        version_file = version_file,
        info_file = info_file,
    )
    cgo_dynamic_deps = [
        d
        for d in archive.cgo_deps.to_list()
        if has_shared_lib_extension(d.basename)
    ]
    runfiles = go._ctx.runfiles(files = cgo_dynamic_deps).merge(archive.runfiles)

    ccinfo = None
    if go.cgo_tools and go.mode.link in (LINKMODE_C_ARCHIVE, LINKMODE_C_SHARED):
        cgo_exports = go.actions.declare_file("%s.h" % name)
        concat_args = go.actions.args()
        concat_args.add("concat")
        concat_args.add("-out", cgo_exports)
        concat_args.add_all(archive.cgo_exports)
        go.actions.run(
            inputs = archive.cgo_exports,
            outputs = [cgo_exports],
            executable = go.toolchain._builder,
            arguments = [concat_args],
        )
        cc_import_kwargs = {
            "hdrs": depset([cgo_exports]),
            "linkopts": {
                "darwin": [],
                "windows": ["-mthreads"],
            }.get(go.mode.goos, ["-pthreads"]),
        }
        if go.mode.link == LINKMODE_C_SHARED:
            cc_import_kwargs["dynamic_library"] = executable
        elif go.mode.link == LINKMODE_C_ARCHIVE:
            cc_import_kwargs["static_library"] = executable
            cc_import_kwargs["alwayslink"] = True
        ccinfo = new_cc_import(go, **cc_import_kwargs)
        ccinfo = cc_common.merge_cc_infos(
            cc_infos = [ccinfo] + [d[CcInfo] for d in source.cdeps],
        )

    return archive, executable, runfiles, ccinfo
