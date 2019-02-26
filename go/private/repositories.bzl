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
        http_archive,
        name = "org_golang_x_tools",
        # master, as of 2019-01-15
        urls = ["https://codeload.github.com/golang/tools/zip/bf090417da8b6150dcfe96795325f5aa78fff718"],
        strip_prefix = "tools-bf090417da8b6150dcfe96795325f5aa78fff718",
        type = "zip",
        patches = [
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_x_tools-extras.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/tools
    )

    # Proto dependencies
    _maybe(
        git_repository,
        name = "com_github_golang_protobuf",
        remote = "https://github.com/golang/protobuf",
        commit = "aa810b61a9c79d51363740d207bb46cf8e620ed5",  # v1.2.0, as of 2018-09-28
        shallow_since = "1534281267 -0700",
        patches = [
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-gazelle.patch",
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/golang/protobuf -proto disable_global
    )

    # bazel_skylib is a dependency of com_google_protobuf.
    # Nothing in rules_go may depend on bazel_skylib, since it won't be declared
    # when go/def.bzl is loaded. The vendored copy of skylib in go/private/skylib
    # may be used instead.
    _maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "54ee22e5b9f0dd2b42eb8a6c1878dee592cfe8eb33223a7dbbc583a383f6ee1a",
        strip_prefix = "bazel-skylib-0.6.0",
        urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.6.0.zip"],
        type = "zip",
    )
    _maybe(
        http_archive,
        name = "com_google_protobuf",
        strip_prefix = "protobuf-3.6.1.3",
        sha256 = "9510dd2afc29e7245e9e884336f848c8a6600a14ae726adb6befdb4f786f0be2",
        # v3.6.1.3 as of 2019-01-15
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.6.1.3.zip"],
        type = "zip",
    )
    _maybe(
        git_repository,
        name = "com_github_mwitkow_go_proto_validators",
        remote = "https://github.com/mwitkow/go-proto-validators",
        commit = "0950a79900071e9f3f5979b78078c599376422fd",  # master, as of 2019-01-15
        shallow_since = "1522745477 +0100",
        patches = ["@io_bazel_rules_go//third_party:com_github_mwitkow_go_proto_validators-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/mwitkow/go-proto-validators -proto disable
    )
    _maybe(
        git_repository,
        name = "com_github_gogo_protobuf",
        remote = "https://github.com/gogo/protobuf",
        commit = "4cbf7e384e768b4e01799441fdf2a706a5635ae7",  # v1.2.0, as of 2019-01-15
        shallow_since = "1544518200 +0200",
        patches = ["@io_bazel_rules_go//third_party:com_github_gogo_protobuf-gazelle.patch"],
        patch_args = ["-p1"],
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
        remote = "https://github.com/golang/net",
        commit = "915654e7eabcea33ae277abbecf52f0d8b7a9fdc",  # master as of 2019-01-15
        shallow_since = "1547150550 +0000",
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_net-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/net
    )
    _maybe(
        git_repository,
        name = "org_golang_x_text",
        remote = "https://github.com/golang/text",
        commit = "f21a4dfb5e38f5895301dc265a8def02365cc3d0",  # v0.3.0, latest as of 2019-01-15
        shallow_since = "1513256923 +0000",
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_text-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/text
    )
    _maybe(
        git_repository,
        name = "org_golang_x_sys",
        remote = "https://github.com/golang/sys",
        commit = "2be51725563103c17124a318f1745b66f2347acb",  # master as of 2019-01-15
        shallow_since = "1547471016 +0000",
        patches = ["@io_bazel_rules_go//third_party:org_golang_x_sys-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/sys
    )
    _maybe(
        git_repository,
        name = "org_golang_google_grpc",
        remote = "https://github.com/grpc/grpc-go",
        commit = "df014850f6dee74ba2fc94874043a9f3f75fbfd8",  # v1.17.0, latest as of 2019-01-15
        shallow_since = "1543966913 -0800",
        patches = [
            "@io_bazel_rules_go//third_party:org_golang_google_grpc-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_google_grpc-crosscompile.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix google.golang.org/grpc -proto disable
    )
    _maybe(
        git_repository,
        name = "org_golang_google_genproto",
        remote = "https://github.com/google/go-genproto",
        commit = "db91494dd46c1fdcbbde05e5ff5eb56df8f7d79a",  # master as of 2019-01-15
        shallow_since = "1547229923 -0800",
        patches = ["@io_bazel_rules_go//third_party:org_golang_google_genproto-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix google.golang.org/genproto -proto disable_global
    )
    _maybe(
        http_archive,
        name = "go_googleapis",
        # master as of 2019-01-17
        urls = ["https://codeload.github.com/googleapis/googleapis/zip/0ac60e21a1aa86c07c1836865b35308ba8178b05"],
        strip_prefix = "googleapis-0ac60e21a1aa86c07c1836865b35308ba8178b05",
        type = "zip",
        patches = [
            "@io_bazel_rules_go//third_party:go_googleapis-directives.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-gazelle.patch",
            "@io_bazel_rules_go//third_party:go_googleapis-fix.patch",
        ],
        patch_args = ["-E", "-p1"],
    )

    # Needed for examples
    _maybe(
        git_repository,
        name = "com_github_golang_glog",
        remote = "https://github.com/golang/glog",
        commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",  # master as of 2019-01-15
        shallow_since = "1453852388 +1100",
        patches = ["@io_bazel_rules_go//third_party:com_github_golang_glog-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/golang/glog
    )
    _maybe(
        git_repository,
        name = "com_github_kevinburke_go_bindata",
        remote = "https://github.com/kevinburke/go-bindata",
        commit = "06af60a4461b70d84a2b173d92f9f425d78baf55",  # v3.11.0, latest as of 2019-01-15
        shallow_since = "1533425175 -0700",
        patches = ["@io_bazel_rules_go//third_party:com_github_kevinburke_go_bindata-gazelle.patch"],
        patch_args = ["-p1"],
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
