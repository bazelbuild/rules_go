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

load("//go/private:common.bzl", "MINIMUM_BAZEL_VERSION")
load("//go/private:skylib/lib/versions.bzl", "versions")
load("//go/private:nogo.bzl", "DEFAULT_NOGO", "go_register_nogo")
load("//proto:gogo.bzl", "gogo_special_proto")
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
        strip_prefix = "platforms-9ded0f9c3144258dad27ad84628845bcd7ca6fe6",
        # master, as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/archive/9ded0f9c3144258dad27ad84628845bcd7ca6fe6.zip",
            "https://github.com/bazelbuild/platforms/archive/9ded0f9c3144258dad27ad84628845bcd7ca6fe6.zip",
        ],
        sha256 = "81394f5999413fcdfe918b254de3c3c0d606fbd436084b904e254b1603ab7616",
    )

    # Needed by rules_go implementation and tests.
    # We can't call bazel_skylib_workspace from here. At the moment, it's only
    # used to register unittest toolchains, which rules_go does not need.
    _maybe(
        http_archive,
        name = "bazel_skylib",
        # 1.0.2, latest as of 2020-05-12
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
        # master, as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/golang/tools/archive/2bc93b1c0c88b2406b967fcd19a623d1ff9ea0cd.zip",
            "https://github.com/golang/tools/archive/2bc93b1c0c88b2406b967fcd19a623d1ff9ea0cd.zip",
        ],
        sha256 = "b05c5b5b9091a35ecb433227ea30aa75cb6b9d9409b308bc75d0975d4a291912",
        strip_prefix = "tools-2bc93b1c0c88b2406b967fcd19a623d1ff9ea0cd",
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

    # Needed by golang.org/x/tools/go/packages
    _maybe(
        http_archive,
        name = "org_golang_x_xerrors",
        # master, as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/golang/xerrors/archive/9bdfabe68543c54f90421aeb9a60ef8061b5b544.zip",
            "https://github.com/golang/xerrors/archive/9bdfabe68543c54f90421aeb9a60ef8061b5b544.zip",
        ],
        sha256 = "757fe99de4d23e10a3343e9790866211ecac0458c5268da43e664a5abeee27e3",
        strip_prefix = "xerrors-9bdfabe68543c54f90421aeb9a60ef8061b5b544",
        patches = [
            # gazelle args: -repo_root -go_prefix golang.org/x/xerrors
            "@io_bazel_rules_go//third_party:org_golang_x_xerrors-gazelle.patch",
        ],
        patch_args = ["-p1"],
    )

    # Needed for additional targets declared around binaries with c-archive
    # and c-shared link modes.
    _maybe(
        git_repository,
        name = "rules_cc",
        remote = "https://github.com/bazelbuild/rules_cc",
        # master, as of 2020-05-21
        commit = "8c31dd406cf17611d7962bee4680cbc4360219ed",
        shallow_since = "1588944954 -0700",
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
        sha256 = "7820cd724e3fdcfe322ed85420662cc21104b901af39a0e505e5059a3cb45a68",
        # v1.22.0, latest as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf-go/archive/v1.22.0.zip",
            "https://github.com/protocolbuffers/protobuf-go/archive/v1.22.0.zip",
        ],
        strip_prefix = "protobuf-go-1.22.0",
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
        # v1.4.1, latest as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/golang/protobuf/archive/v1.4.1.zip",
            "https://github.com/golang/protobuf/archive/v1.4.1.zip",
        ],
        sha256 = "7b6e8ed38df65e08a4446aa09d3596b2cb56f279d8a813a3c491542b790f990d",
        strip_prefix = "protobuf-1.4.1",
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
        # v0.3.0, latest as of 2020-05-12
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
        # v1.3.1, latest as of 2020-05-21
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
        # master, as of 2020-05-21
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/go-genproto/archive/f5ebc3bea3804948c8feb1e2b62323d73add1083.zip",
            "https://github.com/googleapis/go-genproto/archive/f5ebc3bea3804948c8feb1e2b62323d73add1083.zip",
        ],
        sha256 = "e056e969e0dce308a28ff6f626fb4b0006fafc3fd6f300e042f14938106ce386",
        strip_prefix = "go-genproto-f5ebc3bea3804948c8feb1e2b62323d73add1083",
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
        # master, as of 2020-05-21
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/googleapis/archive/bf17ae5fd93929beb44ac4c6b04f5088c3ee4a02.zip",
            "https://github.com/googleapis/googleapis/archive/bf17ae5fd93929beb44ac4c6b04f5088c3ee4a02.zip",
        ],
        sha256 = "56868d9399a0576a2e01ce524e64477cd58ce0bf9ee298490482d1a618b8d11a",
        strip_prefix = "googleapis-bf17ae5fd93929beb44ac4c6b04f5088c3ee4a02",
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
        nogo = DEFAULT_NOGO,
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
