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

def _go_repository_select_impl(ctx):
  os_name = ctx.os.name

  # 1. Configure the goroot path
  if os_name == 'linux':
    go_version = ctx.attr.go_linux_version
  elif os_name == 'mac os x':
    go_version = ctx.attr.go_darwin_version
  else:
    fail("Unsupported operating system: " + os_name)
  if go_version == None:
    fail("No Go toolchain provided for host operating system: " + os_name)
  goroot = ctx.path(go_version).dirname

  # 2. Create the symlinks and write the BUILD file.
  gobin = goroot.get_child("bin")
  gopkg = goroot.get_child("pkg")
  gosrc = goroot.get_child("src")
  ctx.symlink(gobin, "bin")
  ctx.symlink(gopkg, "pkg")
  ctx.symlink(gosrc, "src")

  ctx.file("BUILD", GO_TOOLCHAIN_BUILD_FILE.format(
    goroot = goroot,
  ))


go_repository_select = repository_rule(
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

