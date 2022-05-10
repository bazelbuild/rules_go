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
load("//go/private/skylib/lib:versions.bzl", "versions")
load("//go/private:nogo.bzl", "DEFAULT_NOGO", "go_register_nogo")
load("//proto:gogo.bzl", "gogo_special_proto")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def go_rules_dependencies():
    """Declares workspaces the Go rules depend on. Workspaces that use
    rules_go should call this.

    See https://github.com/bazelbuild/rules_go/blob/master/go/dependencies.rst#overriding-dependencies
    for information on each dependency.

    Instructions for updating this file are in
    https://github.com/bazelbuild/rules_go/wiki/Updating-dependencies.

    PRs updating dependencies are NOT ACCEPTED. See
    https://github.com/bazelbuild/rules_go/blob/master/go/dependencies.rst#overriding-dependencies
    for information on choosing different versions of these repositories
    in your own project.
    """
    if getattr(native, "bazel_version", None):
        versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Needed by rules_go implementation and tests.
    # We can't call bazel_skylib_workspace from here. At the moment, it's only
    # used to register unittest toolchains, which rules_go does not need.
    # releaser:upgrade-dep bazelbuild bazel-skylib
    _maybe(
        http_archive,
        name = "bazel_skylib",
        # 1.2.1, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
        ],
        sha256 = "f7be3474d42aae265405a592bb7da8e171919d74c16f082a5457840f06054728",
        strip_prefix = "",
    )

    # Needed for nogo vet checks and go/packages.
    # releaser:upgrade-dep golang tools
    _maybe(
        http_archive,
        name = "org_golang_x_tools",
        # v0.1.9, latest as of 2022-03-14
        urls = [
            "https://mirror.bazel.build/github.com/golang/tools/archive/v0.1.9.zip",
            "https://github.com/golang/tools/archive/v0.1.9.zip",
        ],
        sha256 = "1d338afb3cd8013cfb035da6831dea2210efb0386c17b9c99b5e84724e3d733a",
        strip_prefix = "tools-0.1.9",
        patches = [
            # deletegopls removes the gopls subdirectory. It contains a nested
            # module with additional dependencies. It's not needed by rules_go.
            # releaser:patch-cmd rm -rf gopls
            Label("//third_party:org_golang_x_tools-deletegopls.patch"),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            Label("//third_party:org_golang_x_tools-gazelle.patch"),
        ],
        patch_args = ["-p1"],
    )

    # releaser:upgrade-dep golang sys
    _maybe(
        http_archive,
        name = "org_golang_x_sys",
        # master, as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/golang/sys/archive/988cb79eb6c60b82d4b236dd5d6ffd415d9a8425.zip",
            "https://github.com/golang/sys/archive/988cb79eb6c60b82d4b236dd5d6ffd415d9a8425.zip",
        ],
        sha256 = "fa11c10192787e5391146d64ebdfd57558837cd19edaf7e8c17da526836dff17",
        strip_prefix = "sys-988cb79eb6c60b82d4b236dd5d6ffd415d9a8425",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/sys -go_naming_convention import_alias
            Label("//third_party:org_golang_x_sys-gazelle.patch"),
        ],
        patch_args = ["-p1"],
    )

    # Needed by golang.org/x/tools/go/packages
    # releaser:upgrade-dep golang xerrors
    _maybe(
        http_archive,
        name = "org_golang_x_xerrors",
        # master, as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/golang/xerrors/archive/2f41105eb62f341cfe208d06de4ee3bdd3a083da.zip",
            "https://github.com/golang/xerrors/archive/2f41105eb62f341cfe208d06de4ee3bdd3a083da.zip",
        ],
        sha256 = "abc22b8b94c0d5abe70afde55afbb1e0f8135cb3a39fb54a851777d4f33ccb12",
        strip_prefix = "xerrors-2f41105eb62f341cfe208d06de4ee3bdd3a083da",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/xerrors -go_naming_convention import_alias
            Label("//third_party:org_golang_x_xerrors-gazelle.patch"),
        ],
        patch_args = ["-p1"],
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
    # releaser:upgrade-dep protocolbuffers protobuf-go
    _maybe(
        http_archive,
        name = "org_golang_google_protobuf",
        sha256 = "dc4339bd2011a230d81d5ec445361efeb78366f1d30a7757e8fbea3e7221080e",
        # v1.28.0, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf-go/archive/v1.28.0.zip",
            "https://github.com/protocolbuffers/protobuf-go/archive/v1.28.0.zip",
        ],
        strip_prefix = "protobuf-go-1.28.0",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix google.golang.org/protobuf -go_naming_convention import_alias -proto disable_global
            Label("//third_party:org_golang_google_protobuf-gazelle.patch"),
        ],
        patch_args = ["-p1"],
    )

    # Legacy protobuf compiler, runtime, and utilities.
    # We still use protoc-gen-go because the new one doesn't support gRPC, and
    # the gRPC compiler doesn't exist yet.
    # We need to apply a patch to enable both go_proto_library and
    # go_library with pre-generated sources.
    # releaser:upgrade-dep golang protobuf
    _maybe(
        http_archive,
        name = "com_github_golang_protobuf",
        # v1.5.2, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/golang/protobuf/archive/v1.5.2.zip",
            "https://github.com/golang/protobuf/archive/v1.5.2.zip",
        ],
        sha256 = "5bd0a70e2f3829db9d0e340887af4e921c5e0e5bb3f8d1be49a934204cb16445",
        strip_prefix = "protobuf-1.5.2",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix github.com/golang/protobuf -go_naming_convention import_alias -proto disable_global
            Label("//third_party:com_github_golang_protobuf-gazelle.patch"),
        ],
        patch_args = ["-p1"],
    )

    # Extra protoc plugins and libraries.
    # Doesn't belong here, but low maintenance.
    # releaser:upgrade-dep mwitkow go-proto-validators
    _maybe(
        http_archive,
        name = "com_github_mwitkow_go_proto_validators",
        # v0.3.2, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/mwitkow/go-proto-validators/archive/v0.3.2.zip",
            "https://github.com/mwitkow/go-proto-validators/archive/v0.3.2.zip",
        ],
        sha256 = "d8697f05a2f0eaeb65261b480e1e6035301892d9fc07ed945622f41b12a68142",
        strip_prefix = "go-proto-validators-0.3.2",
        # Bazel support added in v0.3.0, so no patches needed.
    )

    # releaser:upgrade-dep gogo protobuf
    _maybe(
        http_archive,
        name = "com_github_gogo_protobuf",
        # v1.3.2, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/gogo/protobuf/archive/v1.3.2.zip",
            "https://github.com/gogo/protobuf/archive/v1.3.2.zip",
        ],
        sha256 = "f89f8241af909ce3226562d135c25b28e656ae173337b3e58ede917aa26e1e3c",
        strip_prefix = "protobuf-1.3.2",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix github.com/gogo/protobuf -go_naming_convention import_alias -proto legacy
            Label("//third_party:com_github_gogo_protobuf-gazelle.patch"),
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
    # releaser:upgrade-dep googleapis go-genproto
    _maybe(
        http_archive,
        name = "org_golang_google_genproto",
        # main, as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/go-genproto/archive/f39f71e6c8f3d2f3aa4fd64a01bb28f83376b893.zip",
            "https://github.com/googleapis/go-genproto/archive/f39f71e6c8f3d2f3aa4fd64a01bb28f83376b893.zip",
        ],
        sha256 = "2ce6165564927f9b9983bf8c85d250e2c28ad43b056d7b748cdac7c3a388b6c3",
        strip_prefix = "go-genproto-f39f71e6c8f3d2f3aa4fd64a01bb28f83376b893",
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix google.golang.org/genproto -go_naming_convention import_alias -proto disable_global
            Label("//third_party:org_golang_google_genproto-gazelle.patch"),
        ],
        patch_args = ["-p1"],
    )

    # go_proto_library targets for gRPC and Google APIs.
    # TODO(#1986): migrate to com_google_googleapis. This workspace was added
    # before the real workspace supported Bazel. Gazelle resolves dependencies
    # here. Gazelle should resolve dependencies to com_google_googleapis
    # instead, and we should remove this.
    # releaser:upgrade-dep googleapis googleapis
    _maybe(
        http_archive,
        name = "go_googleapis",
        # master, as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/googleapis/googleapis/archive/10c88bb5c489c8ad1edb0e7f6a17cdd07147966e.zip",
            "https://github.com/googleapis/googleapis/archive/10c88bb5c489c8ad1edb0e7f6a17cdd07147966e.zip",
        ],
        sha256 = "e8b434794608a9af0c0721cfaeedebe37d3676a4ee9dbeed868e5e2982b5abcc",
        strip_prefix = "googleapis-10c88bb5c489c8ad1edb0e7f6a17cdd07147966e",
        patches = [
            # releaser:patch-cmd find . -name BUILD.bazel -delete
            Label("//third_party:go_googleapis-deletebuild.patch"),
            # set gazelle directives; change workspace name
            Label("//third_party:go_googleapis-directives.patch"),
            # releaser:patch-cmd gazelle -repo_root .
            Label("//third_party:go_googleapis-gazelle.patch"),
        ],
        patch_args = ["-E", "-p1"],
    )

    # releaser:upgrade-dep golang mock
    _maybe(
        http_archive,
        name = "com_github_golang_mock",
        # v1.6.0, latest as of 2022-05-09
        urls = [
            "https://mirror.bazel.build/github.com/golang/mock/archive/v1.6.0.zip",
            "https://github.com/golang/mock/archive/v1.6.0.zip",
        ],
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix github.com/golang/mock
            Label("//third_party:com_github_golang_mock-gazelle.patch"),
        ],
        patch_args = ["-p1"],
        sha256 = "604d9ab25b07d60c1b8ba6d3ea2e66873138edeed2e561c5358de804ea421a0e",
        strip_prefix = "mock-1.6.0",
    )

    # This may be overridden by go_register_toolchains, but it's not mandatory
    # for users to call that function (they may declare their own @go_sdk and
    # register their own toolchains).
    _maybe(
        go_register_nogo,
        name = "io_bazel_rules_nogo",
        nogo = DEFAULT_NOGO,
    )

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)
