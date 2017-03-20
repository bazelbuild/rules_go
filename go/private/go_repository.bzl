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


def _go_repository_impl(ctx):
  fetch_repo = ctx.path(ctx.attr._fetch_repo)

  if ctx.attr.commit and ctx.attr.tag:
    fail("cannot specify both of commit and tag", "commit")
  if ctx.attr.commit:
    rev = ctx.attr.commit
  elif ctx.attr.tag:
    rev = ctx.attr.tag
  else:
    fail("neither commit or tag is specified", "commit")

  # TODO(yugui): support submodule?
  # c.f. https://www.bazel.io/versions/master/docs/be/workspace.html#git_repository.init_submodules
  remote = ctx.attr.remote
  vcs = ctx.attr.vcs
  importpath = ctx.attr.importpath
  result = ctx.execute([
      fetch_repo,
      '--dest', ctx.path(''),
      '--remote', remote,
      '--rev', rev,
      '--vcs', vcs,
      '--importpath', importpath])
  if result.return_code:
    fail("failed to fetch %s: %s" % (ctx.name, result.stderr))


def _new_go_repository_impl(ctx):
  _go_repository_impl(ctx)
  gazelle = ctx.path(ctx.attr._gazelle)

  cmds = [gazelle, '--go_prefix', ctx.attr.importpath, '--mode', 'fix',
          '--repo_root', ctx.path(''),
          "--build_tags", ",".join(ctx.attr.build_tags)]
  if ctx.attr.build_file_name:
      cmds += ["--build_file_name", ctx.attr.build_file_name]
  if ctx.attr.rules_go_repo_only_for_internal_use:
    cmds += ["--go_rules_bzl_only_for_internal_use",
             "%s//go:def.bzl" % ctx.attr.rules_go_repo_only_for_internal_use]
  cmds += [ctx.path('')]

  result = ctx.execute(cmds)
  if result.return_code:
    fail("failed to generate BUILD files for %s: %s" % (
        ctx.attr.importpath, result.stderr))


_go_repository_attrs = {
    "build_file_name": attr.string(),
    "importpath": attr.string(),
    "remote": attr.string(),
    "vcs": attr.string(default="", values=["", "git", "hg", "svn", "bzr"]),
    "commit": attr.string(),
    "tag": attr.string(),
    "build_tags": attr.string_list(),
    "_fetch_repo": attr.label(
        default = Label("@io_bazel_rules_go_repository_tools//:bin/fetch_repo"),
        allow_files = True,
        single_file = True,
        executable = True,
        cfg = "host",
    ),
}


go_repository = repository_rule(
    implementation = _go_repository_impl,
    attrs = _go_repository_attrs,
)


new_go_repository = repository_rule(
    implementation = _new_go_repository_impl,
    attrs = _go_repository_attrs + {
        "_gazelle": attr.label(
            default = Label("@io_bazel_rules_go_repository_tools//:bin/gazelle"),
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
        ),
        # See also #135.
        # TODO(yugui) Remove this attribute when we drop support of Bazel 0.3.2.
        "rules_go_repo_only_for_internal_use": attr.string(),
    },
)

# See also #135.
# TODO(yugui) Remove this rule when we drop support of Bazel 0.3.2.
def _buildifier_repository_impl(ctx):
  _go_repository_impl(ctx)
  result = ctx.execute([
      "find", ctx.path(''), '(', '-name', 'BUILD', '-or', '-name', '*.bzl', ')',
      '-exec',
      'sed', '-i', '', '-e', 's!@io_bazel_rules_go//!@//!', '{}',
      ';'])
  if result.return_code:
    fail("Failed to postprocess BUILD files in buildifier: %s" % result.stderr)

buildifier_repository_only_for_internal_use = repository_rule(
    implementation = _buildifier_repository_impl,
    attrs = _go_repository_attrs,
)
