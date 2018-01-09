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

load(
    "@io_bazel_rules_go//go/private:context.bzl",
    go_context = "go_context",
)
load(
    "@io_bazel_rules_go//go/private:go_repository.bzl",
    "go_repository",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    _GoLibrary = "GoLibrary",
)
load(
    "@io_bazel_rules_go//go/private:repositories.bzl",
    "go_rules_dependencies",
    "go_register_toolchains",
)
load(
    "@io_bazel_rules_go//go/private:sdk.bzl",
    go_download_sdk = "go_download_sdk",
    go_host_sdk = "go_host_sdk",
    go_local_sdk = "go_local_sdk",
    go_sdk = "go_sdk",  # DEPRECATED
)
load(
    "@io_bazel_rules_go//go/private:go_toolchain.bzl",
    go_toolchain = "go_toolchain",
)
load(
    "@io_bazel_rules_go//go/private:rules/prefix.bzl",
    "go_prefix",
)
load(
    "@io_bazel_rules_go//go/private:rules/wrappers.bzl",
    _go_binary_macro = "go_binary_macro",
    _go_library_macro = "go_library_macro",
    _go_test_macro = "go_test_macro",
)
load(
    "@io_bazel_rules_go//go/private:rules/source.bzl",
    _go_source = "go_source",
)
load(
    "@io_bazel_rules_go//extras:embed_data.bzl",
    "go_embed_data",
)
load(
    "@io_bazel_rules_go//go/private:tools/gazelle.bzl",
    "gazelle",
)
load(
    "@io_bazel_rules_go//go/private:tools/path.bzl",
    _go_path = "go_path",
)
load(
    "@io_bazel_rules_go//go/private:tools/vet.bzl",
    _go_vet_test = "go_vet_test",
)

# Current version or next version to be tagged. Gazelle and other tools may
# check this to determine compatibility.
RULES_GO_VERSION = "0.9.0"

GoLibrary = _GoLibrary
"""See go/providers.rst#GoLibrary for full documentation."""

go_library = _go_library_macro
"""See go/core.rst#go_library for full documentation."""

go_binary = _go_binary_macro
"""See go/core.rst#go_binary for full documentation."""

go_test = _go_test_macro
"""See go/core.rst#go_test for full documentation."""

go_source = _go_source
"""See go/core.rst#go_test for full documentation."""

go_path = _go_path
"""
    go_path is a rule for creating `go build` compatible file layouts from a set of Bazel.
    targets.
        "deps": attr.label_list(providers=[GoLibrary]), # The set of go libraries to include the export
        "mode": attr.string(default="link", values=["link", "copy"]) # Whether to copy files or produce soft links
"""

go_vet_test = _go_vet_test
"""
    go_vet_test
"""

# Compatability shims
def cgo_genrule(name, tags=[], **kwargs):
  print("DEPRECATED: {0} : cgo_genrule is deprecated. Please migrate to go_library with cgo=True.".format(name))
  return go_library(name=name, tags=tags+["manual"], cgo=True, **kwargs)

def cgo_library(name, **kwargs):
  print("DEPRECATED: {0} : cgo_library is deprecated. Please migrate to go_library with cgo=True.".format(name))
  return go_library(name=name, cgo=True, **kwargs)

def new_go_repository(name, **kwargs):
  print("DEPRECATED: {0} : new_go_repository is deprecated. Please migrate to go_repository soon.".format(name))
  return go_repository(name=name, **kwargs)

def go_repositories(
    go_version = None,
    go_linux = None,
    go_darwin = None):

  print("DEPRECATED: go_repositories has been deprecated. go_rules_dependencies installs dependencies the way nested workspaces should, and go_register_toolchains adds the toolchains")
  go_rules_dependencies()
  if go_version != None:
    go_register_toolchains(go_version=go_version)
  else:
    go_register_toolchains()
