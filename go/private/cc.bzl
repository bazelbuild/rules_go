load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def new_cc_import(go, hdrs=None, **kwargs):
    compilation_info = cc_common.create_compilation_context(
        headers = hdrs,
        includes = depset([hdr.root.path for hdr in hdrs.to_list()]),
    )
    library_to_link = cc_common.create_library_to_link(
        actions = go._ctx.actions,
        cc_toolchain = go.cgo_tools.cc_toolchain,
        feature_configuration = go.cgo_tools.feature_configuration,
        **kwargs
    )
    return CcInfo(
        compilation_context = compilation_info,
        linking_context = cc_common.create_linking_context(
            libraries_to_link = [library_to_link],
        ),
    )
