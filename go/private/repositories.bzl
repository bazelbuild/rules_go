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
load("@io_bazel_rules_go//go/toolchain:toolchains.bzl", "go_register_toolchains")
load("@io_bazel_rules_go//go/platform:list.bzl", "GOOS_GOARCH")
load("@io_bazel_rules_go//proto:gogo.bzl", "gogo_special_proto")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def go_rules_dependencies():
    """See /go/workspace.rst#go-rules-dependencies for full documentation."""
    if getattr(native, "bazel_version", None):
        versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Was needed by Gazelle in the past. Will likely be needed for go/packages
    # and analysis in the future.
    _maybe(
        http_archive,
        name = "org_golang_x_tools",
        # master, as of 2018-09-18
        urls = ["https://codeload.github.com/golang/tools/zip/7b71b077e1f4a3d5f15ca417a16c3b4dbb629b8b"],
        strip_prefix = "tools-7b71b077e1f4a3d5f15ca417a16c3b4dbb629b8b",
        type = "zip",
        patches = ["//third_party:org_golang_x_tools-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/tools
    )

    # Proto dependencies
    _maybe(
        git_repository,
        name = "com_github_golang_protobuf",
        remote = "https://github.com/golang/protobuf",
        commit = "aa810b61a9c79d51363740d207bb46cf8e620ed5",  # v1.2.0, as of 2018-09-28
        patches = [
            "//third_party:com_github_golang_protobuf-gazelle.patch",
            "//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/golang/protobuf -proto disable_global
    )
    _maybe(
        http_archive,
        name = "com_google_protobuf",
        # v3.6.1, latest as of 2018-09-28
        urls = ["https://codeload.github.com/google/protobuf/zip/48cb18e5c419ddd23d9badcfe4e9df7bde1979b2"],
        strip_prefix = "protobuf-48cb18e5c419ddd23d9badcfe4e9df7bde1979b2",
        type = "zip",
    )
    _maybe(
        git_repository,
        name = "com_github_mwitkow_go_proto_validators",
        remote = "https://github.com/mwitkow/go-proto-validators",
        commit = "0950a79900071e9f3f5979b78078c599376422fd",  # master, as of 2018-09-28
        patches = ["//third_party:com_github_mwitkow_go_proto_validators-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/mwitkow/go-proto-validators -proto disable
    )
    _maybe(
        git_repository,
        name = "com_github_gogo_protobuf",
        remote = "https://github.com/gogo/protobuf",
        commit = "636bf0302bc95575d69441b25a2603156ffdddf1",  # v1.1.1, as of 2018-09-28
        patches = ["//third_party:com_github_gogo_protobuf-gazelle.patch"],
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
        commit = "4dfa2610cdf3b287375bbba5b8f2a14d3b01d8de",  # master as of 2018-09-28
        patches = ["//third_party:org_golang_x_net-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/net
    )
    _maybe(
        git_repository,
        name = "org_golang_x_text",
        remote = "https://github.com/golang/text",
        commit = "f21a4dfb5e38f5895301dc265a8def02365cc3d0",  # v0.3.0, latest as of 2018-09-28
        patches = ["//third_party:org_golang_x_text-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/text
    )
    _maybe(
        git_repository,
        name = "org_golang_x_sys",
        remote = "https://github.com/golang/sys",
        commit = "e4b3c5e9061176387e7cea65e4dc5853801f3fb7",  # master as of 2018-09-28
        patches = ["//third_party:org_golang_x_sys-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix golang.org/x/sys
    )
    _maybe(
        git_repository,
        name = "org_golang_google_grpc",
        remote = "https://github.com/grpc/grpc-go",
        commit = "8dea3dc473e90c8179e519d91302d0597c0ca1d1",  # v1.15.0, latest as of 2018-09-28
        patches = [
            "//third_party:org_golang_google_grpc-gazelle.patch",
            "//third_party:org_golang_google_grpc-android.patch",
        ],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix google.golang.org/grpc -proto disable
    )
    _maybe(
        git_repository,
        name = "org_golang_google_genproto",
        remote = "https://github.com/google/go-genproto",
        commit = "c7e5094acea1ca1b899e2259d80a6b0f882f81f8",  # master as of 2018-09-28
        patches = ["//third_party:org_golang_google_genproto-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix google.golang.org/genproto -proto disable_global
    )
    _maybe(
        http_archive,
        name = "go_googleapis",
        # master as of 2018-09-28
        urls = ["https://codeload.github.com/googleapis/googleapis/zip/b71d0c74de0b84f2f10a2c61cd66fbb48873709f"],
        strip_prefix = "googleapis-b71d0c74de0b84f2f10a2c61cd66fbb48873709f",
        type = "zip",
        patches = [
            "//third_party:go_googleapis-directives.patch",
            "//third_party:go_googleapis-gazelle.patch",
            "//third_party:go_googleapis-fix.patch",
        ],
        patch_args = ["-p1"],
    )

    # Needed for examples
    _maybe(
        git_repository,
        name = "com_github_golang_glog",
        remote = "https://github.com/golang/glog",
        commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",  # master as of 2018-09-28
        patches = ["//third_party:com_github_golang_glog-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/golang/glog
    )
    _maybe(
        git_repository,
        name = "com_github_kevinburke_go_bindata",
        remote = "https://github.com/kevinburke/go-bindata",
        commit = "06af60a4461b70d84a2b173d92f9f425d78baf55",  # v3.11.0, latest as of 2018-09-28
        patches = ["//third_party:com_github_kevinburke_go_bindata-gazelle.patch"],
        patch_args = ["-p1"],
        # gazelle args: -go_prefix github.com/kevinburke/go-bindata
    )

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)
