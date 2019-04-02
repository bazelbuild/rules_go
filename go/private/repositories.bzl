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
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def go_rules_dependencies():
    """See /go/workspace.rst#go-rules-dependencies for full documentation."""
    if getattr(native, "bazel_version", None):
        versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Compatibility layer, needed to support older versions of Bazel.
    _maybe(
        go_rules_compat,
        name = "io_bazel_rules_go_compat",
    )

    # Needed for nogo vet checks and go/packages.
    _maybe(
        git_repository,
        name = "org_golang_x_tools",
        # master, as of 2019-03-03
        remote = "https://go.googlesource.com/tools",
        commit = "589c23e65e65055d47b9ad4a99723bc389136265", # master, as of 2019-03-03
        patches = [
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_x_tools-extras.patch",
        ],
        patch_args = ["-p1"],
        shallow_since = "1551386336 +0000",
        # gazelle args: -go_prefix golang.org/x/tools
    )

    # Proto dependencies
    _maybe(
        git_repository,
        name = "com_github_golang_protobuf",
        remote = "https://github.com/golang/protobuf",
        commit = "c823c79ea1570fb5ff454033735a8e68575d1d0f",  # v1.3.0, as of 2019-03-03
        patches = [
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-gazelle.patch",
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
        shallow_since = "1549405252 -0800"
        # gazelle args: -go_prefix github.com/golang/protobuf -proto disable_global
    )

    # bazel_skylib is a dependency of com_google_protobuf.
    # Nothing in rules_go may depend on bazel_skylib, since it won't be declared
    # when go/def.bzl is loaded. The vendored copy of skylib in go/private/skylib
    # may be used instead.
    _maybe(
        git_repository,
        name = "bazel_skylib",
        remote = "https://github.com/bazelbuild/bazel-skylib",
        commit = "6741f733227dc68137512161a5ce6fcf283e3f58",  # 0.7.0, as of 2019-03-03
        shallow_since = "1549647446 +0100",
    )

    _maybe(
        git_repository,
        name = "com_google_protobuf",
        remote = "https://github.com/protocolbuffers/protobuf",
        commit = "582743bf40c5d3639a70f98f183914a2c0cd0680",  # v3.7.0, as of 2019-03-03
    )
    # Workaround for protocolbuffers/protobuf#5472
    # At master, they provide a macro that creates this dependency. We can't
    # load it from here though.
    if "net_zlib" not in native.existing_rules():
        native.bind(
            name = "zlib",
            actual = "@net_zlib//:zlib",
        )
        http_archive(
            name = "net_zlib",
            build_file = "@com_google_protobuf//:third_party/zlib.BUILD",
            sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
            strip_prefix = "zlib-1.2.11",
            urls = ["https://zlib.net/zlib-1.2.11.tar.gz"],
        )

    _maybe(
        git_repository,
        name = "com_github_mwitkow_go_proto_validators",
        remote = "https://github.com/mwitkow/go-proto-validators",
        commit = "1f388280e944c97cc59c75d8c84a704097d1f1d6",  # master, as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:com_github_mwitkow_go_proto_validators-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1549963709 +0000",
        # gazelle args: -go_prefix github.com/mwitkow/go-proto-validators -proto disable
    )

    _maybe(
        git_repository,
        name = "com_github_gogo_protobuf",
        remote = "https://github.com/gogo/protobuf",
        commit = "ba06b47c162d49f2af050fb4c75bcbc86a159d5c",  # v1.2.1, as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:com_github_gogo_protobuf-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1550471403 +0200",
        # gazelle args: -go_prefix github.com/gogo/protobuf -proto legacy
    )

    _maybe(
        gogo_special_proto,
        name = "gogo_special_proto",
    )

    # GRPC dependencies
    _maybe(
        git_repository,
        name = "org_golang_x_net",
        remote = "https://go.googlesource.com/net",
        commit = "16b79f2e4e95ea23b2bf9903c9809ff7b013ce85",  # master, as of 2019-03-3
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_net-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1551482021 +0000",
        # gazelle args: -go_prefix golang.org/x/net
    )

    _maybe(
        git_repository,
        name = "org_golang_x_text",
        remote = "https://go.googlesource.com/text",
        commit = "f21a4dfb5e38f5895301dc265a8def02365cc3d0",  # v0.3.0, latest as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_text-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1513256923 +0000",
        # gazelle args: -go_prefix golang.org/x/text
    )
    _maybe(
        git_repository,
        name = "org_golang_x_sys",
        remote = "https://go.googlesource.com/sys",
        commit = "d455e41777fca6e8a5a79e34a14b8368bc11d9ba",  # master, as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_sys-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1551616002 +0000",
        # gazelle args: -go_prefix golang.org/x/sys
    )

    _maybe(
        git_repository,
        name = "org_golang_google_grpc",
        remote = "https://github.com/grpc/grpc-go",
        commit = "2fdaae294f38ed9a121193c51ec99fecd3b13eb7",  # v1.19.0, latest as of 2019-03-03
        patches = [
            "@io_bazel_rules_go//third_party:org_golang_google_grpc-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_google_grpc-crosscompile.patch",
        ],
        patch_args = ["-p1"],
        shallow_since = "1551206709 -0800",
        # gazelle args: -go_prefix google.golang.org/grpc -proto disable
    )

    _maybe(
        git_repository,
        name = "org_golang_google_genproto",
        remote = "https://github.com/google/go-genproto",
        commit = "4f5b463f9597cbe0dd13a6a2cd4f85e788d27508",  # master, as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:org_golang_google_genproto-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1551303189 -0700",
        # gazelle args: -go_prefix google.golang.org/genproto -proto disable_global
    )

    _maybe(
        git_repository,
        name = "go_googleapis",
        # master as of 2019-01-17
        remote = "https://github.com/googleapis/googleapis",
        commit = "41d72d444fbe445f4da89e13be02078734fb7875",  # master, as of 2019-03-03
        patches = [
            "@io_bazel_rules_go//third_party:go_googleapis-deletebuild.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-directives.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-gazelle.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-fix.patch",
        ],
        patch_args = ["-E", "-p1"],
        shallow_since = "1551404057 -0800",
    )

    # Needed for examples
    _maybe(
        git_repository,
        name = "com_github_golang_glog",
        remote = "https://github.com/golang/glog",
        commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",  # master as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:com_github_golang_glog-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1453852388 +1100",
        # gazelle args: -go_prefix github.com/golang/glog
    )
    _maybe(
        git_repository,
        name = "com_github_kevinburke_go_bindata",
        remote = "https://github.com/kevinburke/go-bindata",
        commit = "53d73b98acf3bd9f56d7f9136ed8e1be64756e1d",  # v3.13.0, latest as of 2019-03-03
        patches = ["@io_bazel_rules_go//third_party:com_github_kevinburke_go_bindata-gazelle.patch"],
        patch_args = ["-p1"],
        shallow_since = "1545009224 +0000",
        # gazelle args: -go_prefix github.com/kevinburke/go-bindata
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
