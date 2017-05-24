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

load("//go/private:toolchain.bzl", "go_sdk_repository", "go_repository_select")
load("//go/private:repository_tools.bzl", "go_repository_tools")
load("//go/private:bzl_format.bzl", "bzl_format_repositories")
load("//go/private:go_repository.bzl", "go_repository")

_sdk_repositories = {
    # 1.8.2 repositories
    'go1.8.2.linux-amd64.tar.gz': '5477d6c9a4f96fa120847fafa88319d7b56b5d5068e41c3587eebe248b939be7',
    'go1.8.2.darwin-amd64.tar.gz': '3f783c33686e6d74f6c811725eb3775c6cf80b9761fa6d4cebc06d6d291be137',
    # 1.8.1 repositories
    'go1.8.1.linux-amd64.tar.gz': 'a579ab19d5237e263254f1eac5352efcf1d70b9dacadb6d6bb12b0911ede8994',
    'go1.8.1.darwin-amd64.tar.gz': '25b026fe2f4de7c80b227f69588b06b93787f5b5f134fbf2d652926c08c04bcd',
    # 1.8 repositories
    'go1.8.linux-amd64.tar.gz': '3ab94104ee3923e228a2cb2116e5e462ad3ebaeea06ff04463479d7f12d27ca',
    'go1.8.darwin-amd64.tar.gz': 'fdc9f98b76a28655a8770a1fc8197acd8ef746dd4d8a60589ce19604ba2a120',
    # 1.7.5 repositories
    'go1.7.5.linux-amd64.tar.gz': '2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3',
    'go1.7.5.darwin-amd64.tar.gz': '2e2a5e0a5c316cf922cf7d59ee5724d49fc35b07a154f6c4196172adfc14b2ca',
}

def go_repositories(
    go_version = None,
    go_linux = None,
    go_darwin = None):

  for filename, sha256 in _sdk_repositories.items():
    name = filename
    for suffix in [".tar.gz", ".zip"]:
        if name.endswith(suffix):
            name = name[:-len(suffix)]
    go_sdk_repository(
        name = name,
        url = "https://storage.googleapis.com/golang/" + filename,
        sha256 = sha256,
        strip_prefix = "go",
    )

  # Needed for gazelle and wtool
  native.http_archive(
      name = "com_github_bazelbuild_buildtools",
      url = "https://codeload.github.com/bazelbuild/buildtools/zip/d5dcc29f2304aa28c29ecb8337d52bb9de908e0c",
      strip_prefix = "buildtools-d5dcc29f2304aa28c29ecb8337d52bb9de908e0c",
      type = "zip",
  )

  # Needed for fetch repo
  go_repository(
      name = "org_golang_x_tools",
      importpath = "golang.org/x/tools",
      urls = ["https://codeload.github.com/golang/tools/zip/3d92dd60033c312e3ae7cac319c792271cf67e37"],
      strip_prefix = "tools-3d92dd60033c312e3ae7cac319c792271cf67e37",
      type = "zip",
  )

  bzl_format_repositories()

  go_repository_select(go_version, go_linux, go_darwin)
  go_repository_tools(name = "io_bazel_rules_go_repository_tools")
