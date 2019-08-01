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
load("@io_bazel_rules_go//go/private:compat/compat_repo.bzl", "go_rules_compat")
load("@io_bazel_rules_go//go/private:skylib/lib/versions.bzl", "versions")
load("@io_bazel_rules_go//go/private:nogo.bzl", "DEFAULT_NOGO", "go_register_nogo")
load("@io_bazel_rules_go//go/platform:list.bzl", "GOOS_GOARCH")
load("@io_bazel_rules_go//proto:gogo.bzl", "gogo_special_proto")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def go_rules_dependencies():
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

    # Compatibility layer, needed to support older versions of Bazel.
    _maybe(
        go_rules_compat,
        name = "io_bazel_rules_go_compat",
    )

    # Needed by rules_go implementation and tests.
    _maybe(
        git_repository,
        name = "bazel_skylib",
        remote = "https://github.com/bazelbuild/bazel-skylib",
        # 0.8.0, latest as of 2019-07-08
        commit = "3721d32c14d3639ff94320c780a60a6e658fb033",
        shallow_since = "1553102012 +0100",
    )

    # Needed for nogo vet checks and go/packages.
    _maybe(
        git_repository,
        name = "org_golang_x_tools",
        remote = "https://go.googlesource.com/tools",
        # "latest", as of 2019-07-08
        commit = "c8855242db9c1762032abe33c2dff50de3ec9d05",
        shallow_since = "1562618051 +0000",
        patches = [
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_x_tools-extras.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/tools
    )

    # Proto dependencies
    # These are limited as much as possible. In most cases, users need to
    # declare these on their own (probably via go_repository rules generated
    # with 'gazelle update-repos -from_file=go.mod). There are several
    # reasons for this:
    #
    # * com_google_protobuf has its own dependency macro. We can't load
    #   the macro here.
    # * org_golang_google_grpc has too many dependencies for us to maintain.
    # * In general, declaring dependencies here confuses users when they
    #   declare their own dependencies later. Bazel ignores these.
    # * Most proto repos are updated more frequently than rules_go, and
    #   we can't keep up.

    # Go protoc plugin and runtime library
    # We need to apply a patch to enable both go_proto_library and
    # go_library with pre-generated sources.
    _maybe(
        git_repository,
        name = "com_github_golang_protobuf",
        remote = "https://github.com/golang/protobuf",
        # v1.3.1 is "latest" as of 2019-07-08
        commit = "b5d812f8a3706043e23a9cd5babf2e5423744d30",
        shallow_since = "1551367169 -0800",
        patches = [
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-gazelle.patch",
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/golang/protobuf -proto disable_global
    )

    # Extra protoc plugins and libraries.
    # Doesn't belong here, but low maintenance.
    _maybe(
        git_repository,
        name = "com_github_mwitkow_go_proto_validators",
        remote = "https://github.com/mwitkow/go-proto-validators",
        # "latest" as of 2019-07-08
        commit = "fbdcedf3a5550890154208a722600dd6af252902",
        shallow_since = "1562622466 +0100",
        patches = ["@io_bazel_rules_go//third_party:com_github_mwitkow_go_proto_validators-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/mwitkow/go-proto-validators -proto disable
    )

    # Extra protoc plugins and libraries
    # Doesn't belong here, but low maintenance.
    _maybe(
        git_repository,
        name = "com_github_gogo_protobuf",
        remote = "https://github.com/gogo/protobuf",
        # v1.2.1, "latest" as of 20190-07-08
        commit = "ba06b47c162d49f2af050fb4c75bcbc86a159d5c",
        shallow_since = "1550471403 +0200",
        patches = ["@io_bazel_rules_go//third_party:com_github_gogo_protobuf-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/gogo/protobuf -proto legacy
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
        git_repository,
        name = "org_golang_google_genproto",
        remote = "https://github.com/google/go-genproto",
        # "latest" as of 2019-07-08
        commit = "3bdd9d9f5532d75d09efb230bd767d265245cfe5",
        shallow_since = "1562600220 -0600",
        patches = ["@io_bazel_rules_go//third_party:org_golang_google_genproto-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix google.golang.org/genproto -proto disable_global
    )

    # go_proto_library targets for gRPC and Google APIs.
    # TODO(#1986): migrate to com_google_googleapis. This workspace was added
    # before the real workspace supported Bazel. Gazelle resolves dependencies
    # here. Gazelle should resolve dependencies to com_google_googleapis
    # instead, and we should remove this.
    _maybe(
        git_repository,
        name = "go_googleapis",
        remote = "https://github.com/googleapis/googleapis",
        # "latest" as of 2019-07-09
        commit = "b4c73face84fefb967ef6c72f0eae64faf67895f",
        shallow_since = "1562194577 -0700",
        patches = [
            "@io_bazel_rules_go//third_party:go_googleapis-deletebuild.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-directives.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-gazelle.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-fix.patch",
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

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)
