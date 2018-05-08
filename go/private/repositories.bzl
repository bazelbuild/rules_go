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
  _maybe(git_repository,
      name = "bazel_gazelle",
      remote = "https://github.com/bazelbuild/bazel-gazelle",
      commit = "7f30ba724af9495b221e2df0f5ac58511179485f", # master as of 2018-05-08
  )

  # Old version of buildtools, before breaking API changes. Old versions of
  # gazelle (0.9) need this. Newer versions vendor this library, so it's only
  # needed by old versions.
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
  # End of Gazelle dependencies.

  _maybe(go_repository_tools,
      name = "io_bazel_rules_go_repository_tools",
  )

  # Proto dependencies
  _maybe(git_repository,
      name = "com_github_golang_protobuf",
      remote = "https://github.com/golang/protobuf",
      commit = "b4deda0973fb4c70b50d226b1af49f3da59f5265",  # v1.1.0, as of 2018-05-07
      overlay = manifest["com_github_golang_protobuf"],
      # build_file_proto_mode = "legacy",
      # importpath = "github.com/golang/protobuf",
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
      commit = "0950a79900071e9f3f5979b78078c599376422fd",  # master, as of 2018-05-07
      overlay = manifest["com_github_mwitkow_go_proto_validators"],
      # build_file_proto_mode = "disable",
      # importpath = "github.com/mwitkow/go-proto-validators",
  )
  _maybe(git_repository,
      name = "com_github_gogo_protobuf",
      remote = "https://github.com/gogo/protobuf",
      commit = "1adfc126b41513cc696b209667c8656ea7aac67c",  # v1.0.0, as of 2018-02-16
      overlay = manifest["com_github_gogo_protobuf"],
      # build_file_proto_mode = "legacy",
  )
  _maybe(gogo_special_proto,
      name = "gogo_special_proto",
  )

  # GRPC dependencies
  _maybe(git_repository,
      name = "org_golang_x_net",
      remote = "https://github.com/golang/net",
      commit = "640f4622ab692b87c2f3a94265e6f579fe38263d",  # master as of 2018-05-07
      overlay = manifest["org_golang_x_net"],
      # importpath = "golang.org/x/net",
  )
  _maybe(git_repository,
      name = "org_golang_x_text",
      remote = "https://github.com/golang/text",
      commit = "f21a4dfb5e38f5895301dc265a8def02365cc3d0",  # v0.3.0, latest as of 2018-04-02
      overlay = manifest["org_golang_x_text"],
  )
  _maybe(git_repository,
      name = "org_golang_google_grpc",
      remote = "https://github.com/grpc/grpc-go",
      commit = "d11072e7ca9811b1100b80ca0269ac831f06d024",  # v1.10.3, latest as of 2018-05-07
      overlay = manifest["org_golang_google_grpc"],
      # build_file_proto_mode = "disable",
      # importpath = "google.golang.org/grpc",
  )
  _maybe(git_repository,
      name = "org_golang_google_genproto",
      remote = "https://github.com/google/go-genproto",
      commit = "86e600f69ee4704c6efbf6a2a40a5c10700e76c2",  # master as of 2018-05-07
      overlay = manifest["org_golang_google_genproto"],
      # build_file_proto_mode = "disable",
      # importpath = "google.golang.org/genproto",
  )

  # Needed for examples
  _maybe(git_repository,
      name = "com_github_golang_glog",
      remote = "https://github.com/golang/glog",
      commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",  # master as of 2018-04-02
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
