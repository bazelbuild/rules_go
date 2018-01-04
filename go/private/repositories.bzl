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

load("@io_bazel_rules_go//go/private:common.bzl", "check_version", "MINIMUM_BAZEL_VERSION")
load("@io_bazel_rules_go//go/private:repository_tools.bzl", "go_repository_tools")
load("@io_bazel_rules_go//go/private:go_repository.bzl", "go_repository")
load("@io_bazel_rules_go//go/private:rules/stdlib.bzl", "go_stdlib")
load("@io_bazel_rules_go//go/toolchain:toolchains.bzl", "go_register_toolchains")
load("@io_bazel_rules_go//go/platform:list.bzl", "GOOS_GOARCH")
load("@io_bazel_rules_go//proto:gogo.bzl", "gogo_special_proto")

def go_rules_dependencies():
  """See /go/workspace.rst#go-rules-dependencies for full documentation."""

  check_version(MINIMUM_BAZEL_VERSION)

  # Needed for gazelle and wtool
  _maybe(native.http_archive,
      name = "com_github_bazelbuild_buildtools",
      # master, as of 2017-08-14
      url = "https://codeload.github.com/bazelbuild/buildtools/zip/799e530642bac55de7e76728fa0c3161484899f6",
      strip_prefix = "buildtools-799e530642bac55de7e76728fa0c3161484899f6",
      type = "zip",
  )

  # New location of Gazelle. Needed by go_repository.
  # TODO(jayconrod): delete this dependency after we've deleted go_repository
  # or moved it into bazel_gazelle.
  _maybe(native.http_archive,
      name = "bazel_gazelle",
      url = "https://github.com/bazelbuild/bazel-gazelle/releases/download/0.8/bazel-gazelle-0.8.tar.gz",
      sha256 = "e3dadf036c769d1f40603b86ae1f0f90d11837116022d9b06e4cd88cae786676",
  )

  # Needed for fetch repo
  _maybe(go_repository,
      name = "org_golang_x_tools",
      # release-branch.go1.9, as of 2017-08-25
      importpath = "golang.org/x/tools",
      urls = ["https://codeload.github.com/golang/tools/zip/5d2fd3ccab986d52112bf301d47a819783339d0e"],
      strip_prefix = "tools-5d2fd3ccab986d52112bf301d47a819783339d0e",
      type = "zip",
  )

  for goos, goarch in GOOS_GOARCH:
    _maybe(go_stdlib,
        name = "go_stdlib_{}_{}_cgo".format(goos, goarch),
        goos = goos,
        goarch = goarch,
        race = False,
        cgo = True,
    )
    _maybe(go_stdlib,
        name = "go_stdlib_{}_{}_pure".format(goos, goarch),
        goos = goos,
        goarch = goarch,
        race = False,
        cgo = False,
    )
    _maybe(go_stdlib,
        name = "go_stdlib_{}_{}_cgo_race".format(goos, goarch),
        goos = goos,
        goarch = goarch,
        race = True,
        cgo = True,
    )
    _maybe(go_stdlib,
        name = "go_stdlib_{}_{}_pure_race".format(goos, goarch),
        goos = goos,
        goarch = goarch,
        race = True,
        cgo = False,
    )

  _maybe(go_repository_tools,
      name = "io_bazel_rules_go_repository_tools",
  )

  # Proto dependencies
  _maybe(go_repository,
      name = "com_github_golang_protobuf",
      importpath = "github.com/golang/protobuf",
      commit = "1e59b77b52bf8e4b449a57e6f79f21226d571845",  # master, as of 2017-11-24
  )
  _maybe(native.http_archive,
      name = "com_google_protobuf",
      # v3.5.1, latest as of 2018-01-11
      url = "https://codeload.github.com/google/protobuf/zip/106ffc04be1abf3ff3399f54ccf149815b287dd9",
      strip_prefix = "protobuf-106ffc04be1abf3ff3399f54ccf149815b287dd9",
      type = "zip",
  )
  _maybe(go_repository,
      name = "com_github_mwitkow_go_proto_validators",
      importpath = "github.com/mwitkow/go-proto-validators",
      commit = "a55ca57f374a8846924b030f534d8b8211508cf0",  # master, as of 2017-11-24
      build_file_proto_mode="disable",
  )
  _maybe(go_repository,
      name = "com_github_gogo_protobuf",
      importpath = "github.com/gogo/protobuf",
      urls = ["https://codeload.github.com/ianthehat/protobuf/zip/41168f6614b7bb144818ec8967b8c702705df564"],
      strip_prefix = "protobuf-41168f6614b7bb144818ec8967b8c702705df564",
      type = "zip",
      build_file_proto_mode="legacy",
  )
  _maybe(gogo_special_proto,
      name = "gogo_special_proto",
  )

  # Only used by deprecated go_proto_library implementation
  _maybe(native.http_archive,
      name = "com_github_google_protobuf",
      url = "https://github.com/google/protobuf/archive/v3.4.0.tar.gz",
      strip_prefix = "protobuf-3.4.0",
  )

  # GRPC dependencies
  _maybe(go_repository,
      name = "org_golang_x_net",
      commit = "a04bdaca5b32abe1c069418fb7088ae607de5bd0",  # master as of 2017-10-10
      importpath = "golang.org/x/net",
  )
  _maybe(go_repository,
      name = "org_golang_x_text",
      commit = "ab5ac5f9a8deb4855a60fab02bc61a4ec770bd49",  # v0.1.0, latest as of 2017-10-10
      importpath = "golang.org/x/text",
  )
  _maybe(go_repository,
      name = "org_golang_google_grpc",
      commit = "f92cdcd7dcdc69e81b2d7b338479a19a8723cfa3",  # v1.6.0, latest as of 2017-10-10
      importpath = "google.golang.org/grpc",
      build_file_proto_mode = "disable",  # use existing generated code
  )
  _maybe(go_repository,
      name = "org_golang_google_genproto",
      commit = "f676e0f3ac6395ff1a529ae59a6670878a8371a6",  # master on 2017-10-10
      importpath = "google.golang.org/genproto",
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_arm",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_linux_arm"],
    sha256 = "b3ed01907b6cb479ed74c56ba5057d96f696920005018dc521388dde188ee091",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_arm64",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_linux_arm64"],
    sha256 = "0b837418bfd98268070cd5145d842e9816f1773ad351b727952b916cccf01d46",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_linux_386",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_linux_386"],
    sha256 = "f26aa27f995ff65ae074a39441316802a0d700386ac2e1f6cc2ae7836f091d68",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_linux_amd64",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_linux_amd64"],
    sha256 = "2304d84a4eb06433ef49fd82dc12acc9babc85b36db9fb6f404841f68bc13823",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_darwin_386",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_darwin_386"],
    sha256 = "0d8295c7fbd545210116cd17a399e281fe18c91b0228af26e78118f2b7b40244",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_darwin_amd64",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_darwin_amd64"],
    sha256 = "16f6c4298fbe978aec4eab5dc928e58e0c407ff99a1d9cde1527f891ca780db7",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_win_386",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_windows_386.exe"],
    sha256 = "2e05f5f3a2ab7369d3ad68faddb59b9ba312304b3a60d2f711b241c16964ba8f",
    executable = True,
  )
  _maybe(native.http_file,
    name = "com_github_go_swagger_win_amd64",
    urls = ["https://github.com/go-swagger/go-swagger/releases/download/0.13.0/swagger_windows_amd64.exe"],
    sha256 = "c678d51206e1b2b86773054ccc52a7af8ee546431a6077a7c288930dc3eb5bc8",
    executable = True,
  )

  # Needed for examples
  _maybe(go_repository,
      name = "com_github_golang_glog",
      commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
      importpath = "github.com/golang/glog",
  )
  _maybe(go_repository,
      name = "com_github_jteeuwen_go_bindata",
      importpath = "github.com/jteeuwen/go-bindata",
      commit = "a0ff2567cfb70903282db057e799fd826784d41d",
  )

def _maybe(repo_rule, name, **kwargs):
  if name not in native.existing_rules():
    repo_rule(name=name, **kwargs)
