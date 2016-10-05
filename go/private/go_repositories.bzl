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

load("//go/private:go_repository.bzl", "go_repository", "new_go_repository")

repository_tool_deps = {
    'buildifier': struct(
        importpath = 'github.com/bazelbuild/buildifier',
        repo = 'https://github.com/bazelbuild/buildifier',
        commit = '0ca1d7991357ae7a7555589af88930d82cf07c0a',
    ),
    'tools': struct(
        importpath = 'golang.org/x/tools',
        repo = 'https://github.com/golang/tools',
        commit = '2bbdb4568e161d12394da43e88b384c6be63928b',
    )
}

def go_internal_tools_deps():
  """only for internal use in rules_go"""
  go_repository(
      name = "io_bazel_buildifier",
      commit = repository_tool_deps['buildifier'].commit,
      importpath = repository_tool_deps['buildifier'].importpath,
  )

  new_go_repository(
      name = "org_golang_x_tools",
      commit = repository_tool_deps['tools'].commit,
      importpath = repository_tool_deps['tools'].importpath,
  )

def _fetch_repository_tools_deps(ctx, goroot, gopath):
  for name, dep in repository_tool_deps.items():
    result = ctx.execute(['mkdir', '-p', ctx.path('src/' + dep.importpath)])
    if result.return_code:
      fail('failed to create directory: %s' % result.stderr)
    ctx.download_and_extract(
        '%s/archive/%s.zip' % (dep.repo, dep.commit),
        'src/%s' % dep.importpath, '', 'zip', '%s-%s' % (name, dep.commit))

  result = ctx.execute([
      'env', 'GOROOT=%s' % goroot, 'GOPATH=%s' % gopath, 'PATH=%s/bin' % goroot,
      'go', 'generate', 'github.com/bazelbuild/buildifier/core'])
  if result.return_code:
    fail("failed to go genrate: %s" % result.stderr)

_GO_REPOSITORY_TOOLS_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "fetch_repo",
    srcs = ["bin/fetch_repo"],
)

filegroup(
    name = "gazelle",
    srcs = ["bin/gazelle"],
)
"""

def _go_repository_tools_impl(ctx):
  go_tool = ctx.path(ctx.attr._go_tool)
  goroot = go_tool.dirname.dirname
  gopath = ctx.path('')
  prefix = "github.com/bazelbuild/rules_go/" + ctx.attr._tools.package
  src_path = ctx.path(ctx.attr._tools).dirname

  _fetch_repository_tools_deps(ctx, goroot, gopath)

  for t, pkg in [("gazelle", 'gazelle/gazelle'), ("fetch_repo", "fetch_repo")]:
    ctx.symlink("%s/%s" % (src_path, t), "src/%s/%s" % (prefix, t))

    result = ctx.execute([
        'env', 'GOROOT=%s' % goroot, 'GOPATH=%s' % gopath,
        go_tool, "build",
        "-o", ctx.path("bin/" + t), "%s/%s" % (prefix, pkg)])
    if result.return_code:
      fail("failed to build %s: %s" % (t, result.stderr))
  ctx.file('BUILD', _GO_REPOSITORY_TOOLS_BUILD_FILE, False)

_go_repository_tools = repository_rule(
    _go_repository_tools_impl,
    attrs = {
        "_tools": attr.label(
            default = Label("//go/tools:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_go_tool": attr.label(
            default = Label("@io_bazel_rules_go_toolchain//:bin/go"),
            allow_files = True,
            single_file = True,
        ),
        "_x_tools": attr.label(
            default = Label("@org_golang_x_tools//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_buildifier": attr.label(
            default = Label("@io_bazel_buildifier//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
    },
)

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


def _go_repository_select_impl(ctx):
  os = ctx.os.name
  # NOTE: This mapping cannot be table-driven to prevent
  # Bazel from downloading the other archive.
  if os == 'linux':
    goroot = ctx.path(ctx.attr._linux).dirname
  elif os == 'mac os x':
    goroot = ctx.path(ctx.attr._darwin).dirname
  else:
    fail("unsupported operating system: " + os)

  ctx.symlink(goroot, ctx.path(''))
  ctx.file("WORKSPACE", "workspace(name = '%s')" % ctx.name)

_go_repository_select = repository_rule(
    _go_repository_select_impl,
    attrs = {
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
    },
)


def go_repositories():
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

  _go_repository_select(
      name = "io_bazel_rules_go_toolchain",
  )
  _go_repository_tools(
      name = "io_bazel_rules_go_repository_tools",
  )
