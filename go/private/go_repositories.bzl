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

load("//go/private:go_repository.bzl", "buildifier_repository_only_for_internal_use", "new_go_repository")

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
  # c.f. #135
  # TODO(yugui) Simply use go_repository when we drop support of Bazel 0.3.2.
  buildifier_repository_only_for_internal_use(
      name = "io_bazel_buildifier",
      commit = repository_tool_deps['buildifier'].commit,
      importpath = repository_tool_deps['buildifier'].importpath,
  )

  new_go_repository(
      name = "org_golang_x_tools",
      commit = repository_tool_deps['tools'].commit,
      importpath = repository_tool_deps['tools'].importpath,
      # c.f. #135
      # TODO(yugui) Remove this attribute when we drop support of Bazel 0.3.2.
      rules_go_repo_only_for_internal_use = "@",
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
    },
)

GO_TOOLCHAIN_BUILD_FILE = """
load("{rules_go_repo}//go/private:go_root.bzl", "go_root")

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

go_root(
  name = "go_root",
  path = "{goroot}",
)
"""

def _go_repository_select_impl(ctx):
  os_name = ctx.os.name

  # 1. Configure the goroot path
  if os_name == 'linux':
    goroot = ctx.path(ctx.attr._linux).dirname
  elif os_name == 'mac os x':
    goroot = ctx.path(ctx.attr._darwin).dirname
  else:
    fail("Unsupported operating system: " + os_name)

  # 2. Create the symlinks and write the BUILD file.
  gobin = goroot.get_child("bin")
  gopkg = goroot.get_child("pkg")
  gosrc = goroot.get_child("src")
  ctx.symlink(gobin, "bin")
  ctx.symlink(gopkg, "pkg")
  ctx.symlink(gosrc, "src")

  cross_targets = (
      ('linux', 'amd64'),
      ('linux', 'arm'),
      ('linux', '386'),
      ('darwin', 'amd64'),
      ('freebsd', 'amd64'),
  )

  for goos, goarch in cross_targets:
    result = ctx.execute([
        'env', 'GOROOT=%s' % goroot, 'PATH=%s/bin' % goroot,
        'GOOS=%s' % goos, 'GOARCH=%s' % goarch,
        'go', 'install', 'std'])
    if result.return_code:
      fail("failed to install cross compiled stdlib: %s" % result.stderr)

  ctx.file("BUILD", GO_TOOLCHAIN_BUILD_FILE.format(
    goroot = goroot,
    rules_go_repo = ctx.attr.rules_go_repo_only_for_internal_use,
  ))


_go_repository_select = repository_rule(
    _go_repository_select_impl,
    attrs = {
        "rules_go_repo_only_for_internal_use": attr.string(
            default = "@io_bazel_rules_go",
        ),

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


# c.f. #135
# TODO(yugui) remove the attribute rules_go_repo_only_for_internal_use when we
# drop support of Bazel 0.3.2
def go_repositories(
    rules_go_repo_only_for_internal_use = "@io_bazel_rules_go",
    omit_go=False):
  
  if not omit_go:
    native.new_http_archive(
      name =  "golang_linux_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.3.linux-amd64.tar.gz",
      build_file_content = "",
      sha256 = "508028aac0654e993564b6e2014bf2d4a9751e3b286661b0b0040046cf18028e",
      strip_prefix = "go",
    )

    native.new_http_archive(
      name = "golang_darwin_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.3.darwin-amd64.tar.gz",
      build_file_content = "",
      sha256 = "2ef310fa48b43dfed7b4ae063b5facba130ed0db95745c538dfc3e30e7c0de04",
      strip_prefix = "go",
    )

  _go_repository_select(
      name = "io_bazel_rules_go_toolchain",
      rules_go_repo_only_for_internal_use = rules_go_repo_only_for_internal_use,
  )
  _go_repository_tools(
      name = "io_bazel_rules_go_repository_tools",
  )
