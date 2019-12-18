# Copyright 2019 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:common.bzl", "as_iterable")
load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
)

# Compatibility for --incompatible_disable_legacy_cc_provider

CC_PROVIDER_NAME = CcInfo

def has_cc(target):
    return CcInfo in target

def cc_transitive_headers(target):
    return target[CcInfo].compilation_context.headers

def cc_defines(target):
    return target[CcInfo].compilation_context.defines.to_list()

def cc_system_includes(target):
    return target[CcInfo].compilation_context.system_includes.to_list()

def cc_includes(target):
    return target[CcInfo].compilation_context.includes.to_list()

def cc_quote_includes(target):
    return target[CcInfo].compilation_context.quote_includes.to_list()

def cc_link_flags(target):
    return target[CcInfo].linking_context.user_link_flags

def cc_libs(target):
    # Copied from get_libs_for_static_executable in migration instructions
    # from bazelbuild/bazel#7036.
    libraries_to_link = as_iterable(target[CcInfo].linking_context.libraries_to_link)
    libs = []
    for library_to_link in libraries_to_link:
        if library_to_link.static_library != None:
            libs.append(library_to_link.static_library)
        elif library_to_link.pic_static_library != None:
            libs.append(library_to_link.pic_static_library)
        elif library_to_link.interface_library != None:
            libs.append(library_to_link.interface_library)
        elif library_to_link.dynamic_library != None:
            libs.append(library_to_link.dynamic_library)
    return libs

def cc_toolchain_all_files(ctx):
    return find_cpp_toolchain(ctx).all_files.to_list()

# Compatibility for --incompatible_disable_legacy_proto_provider

PROTO_PROVIDER_NAME = ProtoInfo

def has_proto(target):
    return ProtoInfo in target

def get_proto(target):
    return target[ProtoInfo]

def proto_check_deps_sources(target):
    return target[ProtoInfo].check_deps_sources

def proto_source_root(target):
    return target[ProtoInfo].proto_source_root

# Compatibility for --incompatible_disallow_struct_provider
def providers_with_coverage(ctx, source_attributes, dependency_attributes, extensions, providers):
    return providers + [coverage_common.instrumented_files_info(
        ctx,
        source_attributes = source_attributes,
        dependency_attributes = dependency_attributes,
        extensions = extensions,
    )]

# Compatibility for --incompatible_require_ctx_in_configure_features
def cc_configure_features(ctx, cc_toolchain, requested_features, unsupported_features):
    return cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = requested_features,
        unsupported_features = unsupported_features,
    )
