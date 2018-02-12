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
load("@io_bazel_rules_go//go/private:repository_tools.bzl", "go_repository_tools")
load("@io_bazel_rules_go//go/private:skylib/lib/versions.bzl", "versions")
load("@io_bazel_rules_go//go/private:tools/overlay_repository.bzl", "git_repository", "http_archive")
load("@io_bazel_rules_go//go/toolchain:toolchains.bzl", "go_register_toolchains")
load("@io_bazel_rules_go//go/platform:list.bzl", "GOOS_GOARCH")
load("@io_bazel_rules_go//proto:gogo.bzl", "gogo_special_proto")
load("@io_bazel_rules_go//third_party:manifest.bzl", "manifest")

def go_rules_dependencies():
  """See /go/workspace.rst#go-rules-dependencies for full documentation."""
  versions.check(MINIMUM_BAZEL_VERSION)

  # Gazelle and dependencies. These are needed for go_repository.
  # TODO(jayconrod): delete all of these when we've migrated everyone to
  # Gazelle's version of go_repository.
  _maybe(http_archive,
      name = "bazel_gazelle",
      urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.9/bazel-gazelle-0.9.tar.gz"],
      sha256 = "0103991d994db55b3b5d7b06336f8ae355739635e0c2379dea16b8213ea5a223",
  )

  _maybe(http_archive,
      name = "com_github_bazelbuild_buildtools",
      # master, as of 2017-08-14
      urls = ["https://codeload.github.com/bazelbuild/buildtools/zip/799e530642bac55de7e76728fa0c3161484899f6"],
      strip_prefix = "buildtools-799e530642bac55de7e76728fa0c3161484899f6",
      type = "zip",
  )

  _maybe(http_archive,
      name = "org_golang_x_tools",
      # release-branch.go1.9, as of 2017-08-25
      urls = ["https://codeload.github.com/golang/tools/zip/5d2fd3ccab986d52112bf301d47a819783339d0e"],
      strip_prefix = "tools-5d2fd3ccab986d52112bf301d47a819783339d0e",
      type = "zip",
      overlay = manifest["org_golang_x_tools"],
  )

  _maybe(git_repository,
      name = "com_github_pelletier_go_toml",
      remote = "https://github.com/pelletier/go-toml",
      commit = "16398bac157da96aa88f98a2df640c7f32af1da2", # v1.0.1 as of 2017-12-19
      overlay = manifest["com_github_pelletier_go_toml"],
  )
  # End of Gazelle dependencies.k

  _maybe(go_repository_tools,
      name = "io_bazel_rules_go_repository_tools",
  )

  # Proto dependencies
  _maybe(git_repository,
      name = "com_github_golang_protobuf",
      remote = "https://github.com/golang/protobuf",
      commit = "1e59b77b52bf8e4b449a57e6f79f21226d571845",  # master, as of 2017-11-24
      overlay = manifest["com_github_golang_protobuf"],
  )
  _maybe(http_archive,
      name = "com_google_protobuf",
      # v3.5.1, latest as of 2018-01-11
      urls = ["https://codeload.github.com/google/protobuf/zip/106ffc04be1abf3ff3399f54ccf149815b287dd9"],
      strip_prefix = "protobuf-106ffc04be1abf3ff3399f54ccf149815b287dd9",
      type = "zip",
  )
  _maybe(git_repository,
      name = "com_github_mwitkow_go_proto_validators",
      remote = "https://github.com/mwitkow/go-proto-validators",
      commit = "a55ca57f374a8846924b030f534d8b8211508cf0",  # master, as of 2017-11-24
      overlay = manifest["com_github_mwitkow_go_proto_validators"],
  )
  _maybe(http_archive,
      name = "com_github_gogo_protobuf",
      urls = ["https://codeload.github.com/ianthehat/protobuf/zip/41168f6614b7bb144818ec8967b8c702705df564"],
      strip_prefix = "protobuf-41168f6614b7bb144818ec8967b8c702705df564",
      type = "zip",
      overlay = manifest["com_github_gogo_protobuf"],
  )
  _maybe(gogo_special_proto,
      name = "gogo_special_proto",
  )

  # Only used by deprecated go_proto_library implementation
  _maybe(http_archive,
      name = "com_github_google_protobuf",
      urls = ["https://github.com/google/protobuf/archive/v3.4.0.tar.gz"],
      strip_prefix = "protobuf-3.4.0",
  )

  # GRPC dependencies
  _maybe(git_repository,
      name = "org_golang_x_net",
      remote = "https://github.com/golang/net",
      commit = "a04bdaca5b32abe1c069418fb7088ae607de5bd0",  # master as of 2017-10-10
      overlay = manifest["org_golang_x_net"],
  )
  _maybe(git_repository,
      name = "org_golang_x_text",
      remote = "https://github.com/golang/text",
      commit = "ab5ac5f9a8deb4855a60fab02bc61a4ec770bd49",  # v0.1.0, latest as of 2017-10-10
      overlay = manifest["org_golang_x_text"],
  )
  _maybe(git_repository,
      name = "org_golang_google_grpc",
      remote = "https://github.com/grpc/grpc-go",
      commit = "f92cdcd7dcdc69e81b2d7b338479a19a8723cfa3",  # v1.6.0, latest as of 2017-10-10
      overlay = manifest["org_golang_google_grpc"],
  )
  _maybe(git_repository,
      name = "org_golang_google_genproto",
      remote = "https://github.com/google/go-genproto",
      commit = "f676e0f3ac6395ff1a529ae59a6670878a8371a6",  # master on 2017-10-10
      overlay = manifest["org_golang_google_genproto"],
  )

  # Needed for examples
  _maybe(git_repository,
      name = "com_github_golang_glog",
      remote = "https://github.com/golang/glog",
      commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
      overlay = manifest["com_github_golang_glog"],
  )
  _maybe(git_repository,
      name = "com_github_kevinburke_go_bindata",
      remote = "https://github.com/kevinburke/go-bindata",
      commit = "95df019c0747a093fef2832ae530a37fd2766d16",  # v3.7.0, latest as of 2018-02-07
      overlay = manifest["com_github_kevinburke_go_bindata"],
  )

def _maybe(repo_rule, name, **kwargs):
  if name not in native.existing_rules():
    repo_rule(name=name, **kwargs)
