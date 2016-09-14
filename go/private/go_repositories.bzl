# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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
  name = "go_include",
  srcs = [ "pkg/include" ],
)
"""

GO_ROOT_ADDENDUM = """
load("@io_bazel_rules_go//go/private:go_root.bzl", "go_root")

go_root(
  name = "go_root",
  path = "{goroot}",
)
"""

def _go_toolchain_impl(ctx):
  """Symlinks the correct go toolchain."""

  bazel_goroot = ctx.os.environ.get("BAZEL_GOROOT", None)

  # 1. Configure the goroot path
  if bazel_goroot:
    goroot = ctx.path(bazel_goroot)
  else:
    os_name = ctx.os.name
    # NOTE: This mapping cannot be table-driven to prevent
    # Bazel from downloading the other archive.
    if os_name == 'linux':
      goroot = ctx.path(ctx.attr._linux).dirname
    elif os_name == 'mac os x':
      goroot = ctx.path(ctx.attr._darwin).dirname
    else:
      fail("unsupported operating system: " + os_name)

  # 2. Create the symlinks and write the BUILD file.
  gobin = goroot.get_child("bin")
  gopkg = goroot.get_child("pkg")
  ctx.symlink(gobin, "bin")
  ctx.symlink(gopkg, "pkg")
  ctx.file("BUILD", GO_TOOLCHAIN_BUILD_FILE + GO_ROOT_ADDENDUM.format(
    goroot = goroot,
  ), False)

  # 3. If the user has specified the goroot explicitly, confirm a
  # working installation by checking the output of 'go version'.
  if bazel_goroot:
    go = gobin.get_child("go")
    result = ctx.execute([go, "env"])
    if result.return_code:
      fail("""
Something's not right.  Are you sure '%s' points to a functional GOROOT?
--> %s
""" % (go, result.stderr))


_go_toolchain = repository_rule(
      _go_toolchain_impl,
      attrs = {
        #"goroot": attr.string(),
        "_linux": attr.label(
            default = Label("@golang_linux_amd64//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_darwin": attr.label(
            default = Label("@golang_darwin_amd64//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        # "go_root": attr.label(
        #   providers = ["go_root"],
        #   default = Label(
        #     "//:go_root",
        #     relative_to_caller_repository = False
        #   ),
        #   allow_files = False,
        # ),
    },
)

def go_repositories():
  """Provide workspace dependencies including the go toolchain.  If the
  environment variable "BAZEL_GOROOT" is set rules_go will use it
  rather than downloading a toolchain.
  """
  native.new_http_archive(
      name =  "golang_linux_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz",
      build_file_content = GO_TOOLCHAIN_BUILD_FILE,
      sha256 = "43ad621c9b014cde8db17393dc108378d37bc853aa351a6c74bf6432c1bbd182",
      strip_prefix = "go",
  )

  native.new_http_archive(
      name = "golang_darwin_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.1.darwin-amd64.tar.gz",
      build_file_content = GO_TOOLCHAIN_BUILD_FILE,
      sha256 = "9fd80f19cc0097f35eaa3a52ee28795c5371bb6fac69d2acf70c22c02791f912",
      strip_prefix = "go",
  )

  _go_toolchain(
      name = "io_bazel_rules_go_toolchain",
  )
