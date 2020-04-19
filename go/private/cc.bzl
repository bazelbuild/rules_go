load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def new_cc_import(go,
        hdrs = None,
        defines = None,
        local_defines = None,
        dynamic_library = None,
        static_library = None,
        alwayslink = False,
        linkopts = None,
    ):
    compilation_info = cc_common.create_compilation_context(
        defines = defines or depset([]),
        local_defines = local_defines or depset([]),
        headers = hdrs or depset([]),
        includes = depset([hdr.root.path for hdr in hdrs.to_list()]),
    )
    library_to_link = cc_common.create_library_to_link(
        actions = go._ctx.actions,
        cc_toolchain = go.cgo_tools.cc_toolchain,
        feature_configuration = go.cgo_tools.feature_configuration,
        dynamic_library = dynamic_library,
        static_library = static_library,
        alwayslink = alwayslink,
    )
    return CcInfo(
        compilation_context = compilation_info,
        linking_context = cc_common.create_linking_context(
            libraries_to_link = [library_to_link],
            user_link_flags = linkopts,
        ),
    )
