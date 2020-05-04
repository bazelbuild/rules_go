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

# Once nested repositories work, this file should cease to exist.

load("@io_bazel_rules_go//go/private:common.bzl", "MINIMUM_BAZEL_VERSION")
load("@io_bazel_rules_go//go/private:skylib/lib/versions.bzl", "versions")
load("@io_bazel_rules_go//go/private:nogo.bzl", "go_register_nogo")
load("@io_bazel_rules_go//proto:gogo.bzl", "gogo_special_proto")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def go_rules_dependencies(is_rules_go = False):
    """Declares workspaces the Go rules depend on. Workspaces that use
    rules_go should call this.

    See https://github.com/bazelbuild/rules_go/blob/master/go/workspace.rst#overriding-dependencies
    for information on each dependency.

    Instructions for updating this file are in
    https://github.com/bazelbuild/rules_go/wiki/Updating-dependencies.

    PRs updating dependencies are NOT ACCEPTED. See
    https://github.com/bazelbuild/rules_go/blob/master/go/workspace.rst#overriding-dependencies
    for information on choosing different versions of these repositories
    in your own project.
    """
    if getattr(native, "bazel_version", None):
        versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Repository of standard constraint settings and values.
    # Bazel declares this automatically after 0.28.0, but it's better to
    # define an explicit version.
    _maybe(
        http_archive,
        name = "platforms",
        strip_prefix = "platforms-46993efdd33b73649796c5fc5c9efb193ae19d51",
        # master, as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/archive/46993efdd33b73649796c5fc5c9efb193ae19d51.zip",
            "https://github.com/bazelbuild/platforms/archive/46993efdd33b73649796c5fc5c9efb193ae19d51.zip",
        ],
        sha256 = "66184688debeeefcc2a16a2f80b03f514deac8346fe888fb7e691a52c023dd88",
    )

    # Needed by rules_go implementation and tests.
    # We can't call bazel_skylib_workspace from here. At the moment, it's only
    # used to register unittest toolchains, which rules_go does not need.
    _maybe(
        http_archive,
        name = "bazel_skylib",
        # 1.0.2, latest as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
    )

    # Needed for nogo vet checks and go/packages.
    _maybe(
        http_archive,
        name = "org_golang_x_tools",
        # master, as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/golang/tools/archive/57f3fb51f5075e8af9f6ae8bd25e374f4e6b92ed.zip",
            "https://github.com/golang/tools/archive/57f3fb51f5075e8af9f6ae8bd25e374f4e6b92ed.zip",
        ],
        sha256 = "cfd9f941c397e6809117a9893bfe53683d963f58fcd3b9d44a2d784eaaacbade",
        strip_prefix = "tools-57f3fb51f5075e8af9f6ae8bd25e374f4e6b92ed",
        patches = [
            # deletegopls removes the gopls subdirectory. It contains a nested
            # module with additional dependencies. It's not needed by rules_go.
            "@io_bazel_rules_go//third_party:org_golang_x_tools-deletegopls.patch",
            # gazelle args: -repo_root . -go_prefix golang.org/x/tools
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            # extras adds go_tool_library rules for packages under
            # go/analysis/passes and their dependencies. These are needed by
            # nogo.
            "@io_bazel_rules_go//third_party:org_golang_x_tools-extras.patch",
        ],
        patch_args = ["-p1"],
    )

    # Needed for additional targets declared around binaries with c-archive
    # and c-shared link modes.
    _maybe(
        git_repository,
        name = "rules_cc",
        remote = "https://github.com/bazelbuild/rules_cc",
        # master, as of 2020-02-21
        commit = "726dd8157557f1456b3656e26ab21a1646653405",
        shallow_since = "1582107762 -0800",
    )

    # Proto dependencies
    # These are limited as much as possible. In most cases, users need to
    # declare these on their own (probably via go_repository rules generated
    # with 'gazelle update-repos -from_file=go.mod). There are several
    # reasons for this:
    #
    # * com_google_protobuf has its own dependency macro. We can't load
    #   the macro here.
    # * rules_proto also has a dependency macro. It's only needed by tests and
    #   by gogo_special_proto. Users will need to declare it anyway.
    # * org_golang_google_grpc has too many dependencies for us to maintain.
    # * In general, declaring dependencies here confuses users when they
    #   declare their own dependencies later. Bazel ignores these.
    # * Most proto repos are updated more frequently than rules_go, and
    #   we can't keep up.

    # Go protobuf runtime library and utilities.
    _maybe(
        http_archive,
        name = "org_golang_google_protobuf",
        sha256 = "22c82408718787bfa0453563a83681fc3905126040d6901eb1ce399795292937",
        # v1.21.0, latest as of 2020-04-22
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf-go/archive/v1.21.0.zip",
            "https://github.com/protocolbuffers/protobuf-go/archive/v1.21.0.zip",
        ],
        strip_prefix = "protobuf-go-1.21.0",
        patches = [
            # gazelle args: -repo_root . -go_prefix google.golang.org/protobuf -proto disable_global
            "@io_bazel_rules_go//third_party:org_golang_google_protobuf-gazelle.patch",
        ],
        patch_args = ["-p1"],
    )

    # Legacy protobuf compiler, runtime, and utilities.
    # We still use protoc-gen-go because the new one doesn't support gRPC, and
    # the gRPC compiler doesn't exist yet.
    # We need to apply a patch to enable both go_proto_library and
    # go_library with pre-generated sources.
    _maybe(
        http_archive,
        name = "com_github_golang_protobuf",
        # v1.4.0, latest as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/golang/protobuf/archive/v1.4.0.zip",
            "https://github.com/golang/protobuf/archive/v1.4.0.zip",
        ],
        sha256 = "9f74fe5ee107c75523d0d5ab1100a18e3e1e7d24f870b460083ab0a20966b910",
        strip_prefix = "protobuf-1.4.0",
        patches = [
            # gazelle args: -repo_root . -go_prefix github.com/golang/protobuf -proto disable_global
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-gazelle.patch",
            # additional targets may depend on generated code for well known types
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
    )

    # Extra protoc plugins and libraries.
    # Doesn't belong here, but low maintenance.
    _maybe(
        http_archive,
        name = "com_github_mwitkow_go_proto_validators",
        # v0.3.0, latest as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/mwitkow/go-proto-validators/archive/v0.3.0.zip",
            "https://github.com/mwitkow/go-proto-validators/archive/v0.3.0.zip",
        ],
        sha256 = "0b5d4bbbdc45d26040a44fca05e84de2a7fa21ea3ad4418e0748fc9befaaa50c",
        strip_prefix = "go-proto-validators-0.3.0",
        # Bazel support added in v0.3.0, so no patches needed.
    )

    _maybe(
        http_archive,
        name = "com_github_gogo_protobuf",
        # v1.3.1, latest as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/gogo/protobuf/archive/v1.3.1.zip",
            "https://github.com/gogo/protobuf/archive/v1.3.1.zip",
        ],
        sha256 = "2056a39c922c7315530fc5b7a6ce10cc83b58c844388c9b2e903a0d8867a8b66",
        strip_prefix = "protobuf-1.3.1",
        patches = [
            # gazelle args: -repo_root . -go_prefix github.com/gogo/protobuf -proto legacy
            "@io_bazel_rules_go//third_party:com_github_gogo_protobuf-gazelle.patch",
        ],
        patch_args = ["-p1"],
    )

    _maybe(
        gogo_special_proto,
        name = "gogo_special_proto",
    )

    # go_library targets with pre-generated sources for Well Known Types
    # and Google APIs.
    # Doesn't belong here, but it would be an annoying source of errors if
    # this weren't generated with -proto disable_global.
    _maybe(
        http_archive,
        name = "org_golang_google_genproto",
        # master, as of 2020-02-21
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/go-genproto/archive/dad8c97a84f542cf0c67e3ab67b1c09e795fb4af.zip",
            "https://github.com/googleapis/go-genproto/archive/dad8c97a84f542cf0c67e3ab67b1c09e795fb4af.zip",
        ],
        sha256 = "715daaaeb965db55af9b122fc4cfe20428702a661d406e1b18d34dadd46cb2b4",
        strip_prefix = "go-genproto-dad8c97a84f542cf0c67e3ab67b1c09e795fb4af",
        patches = [
            # gazelle args: -repo_root . -go_prefix google.golang.org/genproto -proto disable_global
            "@io_bazel_rules_go//third_party:org_golang_google_genproto-gazelle.patch",
        ],
        patch_args = ["-p1"],
    )

    # go_proto_library targets for gRPC and Google APIs.
    # TODO(#1986): migrate to com_google_googleapis. This workspace was added
    # before the real workspace supported Bazel. Gazelle resolves dependencies
    # here. Gazelle should resolve dependencies to com_google_googleapis
    # instead, and we should remove this.
    _maybe(
        http_archive,
        name = "go_googleapis",
        # master, as of 2020-01-03
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/googleapis/archive/7f910bcc4fc4704947ccfd3ceed015d16b9e00c2.zip",
            "https://github.com/googleapis/googleapis/archive/7f910bcc4fc4704947ccfd3ceed015d16b9e00c2.zip",
        ],
        sha256 = "de3ed11f4caca594d1b832779d20fef115f199c799a09b853bfb35c76a84e205",
        strip_prefix = "googleapis-7f910bcc4fc4704947ccfd3ceed015d16b9e00c2",
        patches = [
            # find . -name BUILD.bazel -delete
            "@io_bazel_rules_go//third_party:go_googleapis-deletebuild.patch",
            # set gazelle directives; change workspace name
            "@io_bazel_rules_go//third_party:go_googleapis-directives.patch",
            # gazelle args: -repo_root .
            "@io_bazel_rules_go//third_party:go_googleapis-gazelle.patch",
        ],
        patch_args = ["-E", "-p1"],
    )

    # This may be overridden by go_register_toolchains, but it's not mandatory
    # for users to call that function (they may declare their own @go_sdk and
    # register their own toolchains).
    _maybe(
        go_register_nogo,
        name = "io_bazel_rules_nogo",
    )

    go_name_hack(
        name = "io_bazel_rules_go_name_hack",
        is_rules_go = is_rules_go,
    )

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)

def _go_name_hack_impl(ctx):
    ctx.file("BUILD.bazel")
    content = "IS_RULES_GO = {}".format(ctx.attr.is_rules_go)
    ctx.file("def.bzl", content)

go_name_hack = repository_rule(
    implementation = _go_name_hack_impl,
    attrs = {
        "is_rules_go": attr.bool(),
    },
    doc = """go_name_hack records whether the main workspace is rules_go.

See documentation for _filter_transition_label in
go/private/rules/transition.bzl.
""",
)
