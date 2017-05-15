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
load("//go/private:bzl_format.bzl", "bzl_format_repositories")

repository_tool_deps = {
    'buildtools': struct(
        importpath = 'github.com/bazelbuild/buildtools',
        repo = 'https://github.com/bazelbuild/buildtools',
        commit = 'd5dcc29f2304aa28c29ecb8337d52bb9de908e0c',
    ),
    'tools': struct(
        importpath = 'golang.org/x/tools',
        repo = 'https://github.com/golang/tools',
        commit = '3d92dd60033c312e3ae7cac319c792271cf67e37',
    )
}

def go_internal_tools_deps():
  """only for internal use in rules_go"""
  go_repository(
      name = "com_github_bazelbuild_buildtools",
      commit = repository_tool_deps['buildtools'].commit,
      importpath = repository_tool_deps['buildtools'].importpath,
  )

  new_go_repository(
      name = "org_golang_x_tools",
      commit = repository_tool_deps['tools'].commit,
      importpath = repository_tool_deps['tools'].importpath,
  )
  bzl_format_repositories()

def _fetch_repository_tools_deps(ctx, goroot, gopath):
  for name, dep in repository_tool_deps.items():
    result = ctx.execute(['mkdir', '-p', ctx.path('src/' + dep.importpath)])
    if result.return_code:
      fail('failed to create directory: %s' % result.stderr)
    archive = name + '.tar.gz'
    ctx.download(
        url = '%s/archive/%s.tar.gz' % (dep.repo, dep.commit),
        output = archive)
    ctx.execute([
        'tar', '-C', 'src/%s' % dep.importpath, '-xf', archive, '--strip', '1'])

  result = ctx.execute([
      'env', 'GOROOT=%s' % goroot, 'GOPATH=%s' % gopath, 'PATH=%s/bin' % goroot,
      'go', 'generate', 'github.com/bazelbuild/buildtools/build'])
  if result.return_code:
    fail("failed to go generate: %s" % result.stderr)

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

go_repository_tools = repository_rule(
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
    },
)
