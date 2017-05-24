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

  _go_repository_select(
      name = "io_bazel_rules_go_toolchain",
      go_linux_version = go_linux_version,
      go_darwin_version = go_darwin_version,
  )
  _go_repository_tools(
      name = "io_bazel_rules_go_repository_tools",
  )
