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

load("//go/private:toolchain.bzl", "go_repository_select")
load("//go/private:repository_tools.bzl", "go_repository_tools")

_GO_VERSIONS_SHA256 = {
    '1.7.5': {
        'linux': '2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3',
        'darwin': '2e2a5e0a5c316cf922cf7d59ee5724d49fc35b07a154f6c4196172adfc14b2ca',
    },
    '1.8': {
        'linux': '53ab94104ee3923e228a2cb2116e5e462ad3ebaeea06ff04463479d7f12d27ca',
        'darwin': '6fdc9f98b76a28655a8770a1fc8197acd8ef746dd4d8a60589ce19604ba2a120',
    },
    '1.8.1': {
        'linux': 'a579ab19d5237e263254f1eac5352efcf1d70b9dacadb6d6bb12b0911ede8994',
        'darwin': '25b026fe2f4de7c80b227f69588b06b93787f5b5f134fbf2d652926c08c04bcd',
    },
    '1.8.2': {
        'linux': '5477d6c9a4f96fa120847fafa88319d7b56b5d5068e41c3587eebe248b939be7',
        'darwin': '3f783c33686e6d74f6c811725eb3775c6cf80b9761fa6d4cebc06d6d291be137',
    },
}

def go_repositories(
    go_version = None,
    go_linux = None,
    go_darwin = None):

  if not go_version and not go_linux and not go_darwin:
    go_version = "1.8.2"

  if go_version:
    if go_linux:
      fail("go_repositories: go_version and go_linux can't both be set")
    if go_darwin:
      fail("go_repositories: go_version and go_darwin can't both be set")
    if go_version not in _GO_VERSIONS_SHA256:
      fail("go_repositories: unsupported version %s; supported versions are %s" %
           (go_version, " ".join(_GO_VERSIONS_SHA256.keys())))
    native.new_http_archive(
        name = "golang_linux_amd64",
        url = "https://storage.googleapis.com/golang/go%s.linux-amd64.tar.gz" % go_version,
        build_file_content = "",
        sha256 = _GO_VERSIONS_SHA256[go_version]["linux"],
        strip_prefix = "go",
    )
    native.new_http_archive(
        name = "golang_darwin_amd64",
        url = "https://storage.googleapis.com/golang/go%s.darwin-amd64.tar.gz" % go_version,
        build_file_content = "",
        sha256 = _GO_VERSIONS_SHA256[go_version]["darwin"],
        strip_prefix = "go",
    )
    go_linux = "@golang_linux_amd64"
    go_darwin = "@golang_darwin_amd64"

  go_linux_version = go_linux + "//:VERSION" if go_linux else None
  go_darwin_version = go_darwin + "//:VERSION" if go_darwin else None

  go_repository_select(
      name = "io_bazel_rules_go_toolchain",
      go_linux_version = go_linux_version,
      go_darwin_version = go_darwin_version,
  )
  go_repository_tools(
      name = "io_bazel_rules_go_repository_tools",
  )
