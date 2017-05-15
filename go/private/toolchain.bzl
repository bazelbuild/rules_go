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

GO_TOOLCHAIN_BUILD_FILE = """
load("@io_bazel_rules_go//go/private:go_root.bzl", "go_root")

package(
  default_visibility = [ "//visibility:public" ])

filegroup(
  name = "toolchain",
  srcs = glob(["bin/*", "pkg/**", ]),
)

filegroup(
  name = "go_tool",
  srcs = [ "bin/go" ],
)

filegroup(
  name = "go_src",
  srcs = glob(["src/**"]),
)

filegroup(
  name = "go_include",
  srcs = [ "pkg/include" ],
)

go_root(
  name = "go_root",
  path = "{goroot}",
)
"""

def _go_sdk_repository_impl(ctx):
  ctx.download_and_extract(
      url = ctx.attr.url,
      stripPrefix = ctx.attr.strip_prefix,
      sha256 = ctx.attr.sha256)
  goroot = ctx.path(".")
  ctx.file("BUILD.bazel", GO_TOOLCHAIN_BUILD_FILE.format(goroot = goroot))

go_sdk_repository = repository_rule(
    implementation = _go_sdk_repository_impl, 
    attrs = {
        "url" : attr.string(),
        "strip_prefix" : attr.string(),
        "sha256" : attr.string(),
    })

def _go_repository_select_impl(ctx):
  os_name = ctx.os.name

  # 1. Configure the goroot path
  if os_name == 'linux':
    go_toolchain = ctx.attr.go_linux_version
  elif os_name == 'mac os x':
    go_toolchain = ctx.attr.go_darwin_version
  else:
    fail("Unsupported operating system: " + os_name)
  if go_toolchain == None:
    fail("No Go toolchain provided for host operating system: " + os_name)
  goroot = ctx.path(go_toolchain).dirname

  # 2. Create the symlinks.
  ctx.symlink(goroot.get_child("bin"), "bin")
  ctx.symlink(goroot.get_child("pkg"), "pkg")
  ctx.symlink(goroot.get_child("src"), "src")
  ctx.symlink(goroot.get_child("BUILD.bazel"), "BUILD.bazel")

_go_repository_select = repository_rule(
    _go_repository_select_impl,
    attrs = {
        "go_linux_version": attr.label(
            allow_files = True,
            single_file = True,
        ),
        "go_darwin_version": attr.label(
            allow_files = True,
            single_file = True,
        ),
    },
)

def go_repository_select(
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
    go_linux = "@go_%s_linux_x86_64" % go_version
    go_darwin = "@go_%s_darwin_x86_64" % go_version

  go_linux_version = go_linux + "//:VERSION" if go_linux else None
  go_darwin_version = go_darwin + "//:VERSION" if go_darwin else None

  _go_repository_select(
      name = "io_bazel_rules_go_toolchain",
      go_linux_version = go_linux_version,
      go_darwin_version = go_darwin_version,
  )
