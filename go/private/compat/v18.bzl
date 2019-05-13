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

# Compatibility for --incompatible_disable_legacy_cc_provider

load("@io_bazel_rules_go//go/private:common.bzl", "as_iterable")

CC_PROVIDER_NAME = "cc"

def has_cc(target):
    return hasattr(target, "cc")

def cc_transitive_headers(target):
    return target.cc.transitive_headers

def cc_defines(target):
    return as_iterable(target.cc.defines)

def cc_system_includes(target):
    return as_iterable(target.cc.system_include_directories)

def cc_includes(target):
    return as_iterable(target.cc.include_directories)

def cc_quote_includes(target):
    return as_iterable(target.cc.quote_include_directories)

def cc_link_flags(target):
    return as_iterable(target.cc.link_flags)

def cc_libs(target):
    return as_iterable(target.cc.libs)

def cc_compile_flags(target):
    return as_iterable(target.cc.compile_flags)

# Compatibility for --incompatible_disable_legacy_proto_provider

PROTO_PROVIDER_NAME = "proto"

def has_proto(target):
    return hasattr(target, "proto")

def get_proto(target):
    return target.proto

def proto_check_deps_sources(target):
    return target.proto.check_deps_sources

def proto_direct_descriptor_set(target):
    return target.proto.direct_descriptor_set

def proto_direct_sources(target):
    return target.proto.direct_sources

def proto_source_root(target):
    # proto_source_root was added in Bazel 0.21.0.
    # Existing code paths check for it.
    return getattr(target.proto, "proto_source_root", None)

def proto_transitive_descriptor_sets(target):
    return target.proto.transitive_descriptor_sets

def proto_transitive_imports(target):
    return target.proto.transitive_imports

def proto_transitive_proto_path(target):
    return target.proto.transitive_proto_path

def proto_transitive_sources(target):
    return target.proto.transitive_sources

# Compatibility for --incompatible_disallow_struct_provider
def providers_with_coverage(ctx, source_attributes, dependency_attributes, extensions, providers):
    return struct(
        providers = providers,
        instrumented_files = struct(
            extensions = extensions,
            source_attributes = source_attributes,
            dependency_attributes = dependency_attributes,
        ),
    )

# Compatibility for --incompatible_require_ctx_in_configure_features
def cc_configure_features(ctx, cc_toolchain, requested_features, unsupported_features):
    return cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        requested_features = requested_features,
        unsupported_features = unsupported_features,
    )
