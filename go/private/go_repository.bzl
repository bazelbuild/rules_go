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
  if ctx.attr.urls:
    # explicit source url
    if ctx.attr.vcs:
      fail("cannot specify both of urls and vcs", "vcs")
    if ctx.attr.commit:
      fail("cannot specify both of urls and commit", "commit")
    if ctx.attr.tag:
      fail("cannot specify both of urls and tag", "tag")
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = ctx.attr.strip_prefix,
        type = ctx.attr.type,
    )
  else:
    if ctx.attr.commit and ctx.attr.tag:
      fail("cannot specify both of commit and tag", "commit")
    if ctx.attr.commit:
      rev = ctx.attr.commit
    elif ctx.attr.tag:
      rev = ctx.attr.tag
    else:
      fail("neither commit or tag is specified", "commit")
    
    # Using fetch repo
    if ctx.attr.vcs and not ctx.attr.remote:
      fail("if vcs is specified, remote must also be")

    fetch_repo_env = {
        "PATH": ctx.os.environ["PATH"],  # to find git
    }
    if "SSH_AUTH_SOCK" in ctx.os.environ:
      fetch_repo_env["SSH_AUTH_SOCK"] = ctx.os.environ["SSH_AUTH_SOCK"]

    # TODO(yugui): support submodule?
    # c.f. https://www.bazel.io/versions/master/docs/be/workspace.html#git_repository.init_submodules
    _fetch_repo = "@io_bazel_rules_go_repository_tools//:bin/fetch_repo"
    if ctx.os.name.startswith('windows'):
      _fetch_repo += ".exe"
    result = env_execute(
        ctx,
        [
            ctx.path(Label(_fetch_repo)),
            '--dest', ctx.path(''),
            '--remote', ctx.attr.remote,
            '--rev', rev,
            '--vcs', ctx.attr.vcs,
            '--importpath', ctx.attr.importpath,
        ],
        environment = fetch_repo_env,
    )
    if result.return_code:
      fail("failed to fetch %s: %s" % (ctx.name, result.stderr))

  generate = ctx.attr.build_file_generation == "on"
  if ctx.attr.build_file_generation == "auto":
    generate = True
    for name in ['BUILD', 'BUILD.bazel', ctx.attr.build_file_name]:
      path = ctx.path(name)
      if path.exists and not env_execute(ctx, ['test', '-f', path]).return_code:
        generate = False
        break
  if generate:
    # Build file generation is needed
    _gazelle = "@io_bazel_rules_go_repository_tools//:bin/gazelle"
    if ctx.os.name.startswith('windows'):
      _gazelle += ".exe"
    gazelle = ctx.path(Label(_gazelle))
    cmds = [gazelle, '--go_prefix', ctx.attr.importpath, '--mode', 'fix',
            '--repo_root', ctx.path(''),
            "--build_tags", ",".join(ctx.attr.build_tags)]
    if ctx.attr.build_file_name:
        cmds += ["--build_file_name", ctx.attr.build_file_name]
    cmds += [ctx.path('')]
    result = env_execute(ctx, cmds)
    if result.return_code:
      fail("failed to generate BUILD files for %s: %s" % (
          ctx.attr.importpath, result.stderr))


go_repository = repository_rule(
    implementation = _go_repository_impl,
    attrs = {
        # Fundamental attributes of a go repository
        "importpath": attr.string(mandatory = True),
        "commit": attr.string(),
        "tag": attr.string(),

        # Attributes for a repository that cannot be inferred from the import path
        "vcs": attr.string(default="", values=["", "git", "hg", "svn", "bzr"]),
        "remote": attr.string(),

        # Attributes for a repository that comes from a source blob not a vcs
        "urls": attr.string_list(),
        "strip_prefix": attr.string(),
        "type": attr.string(),
        "sha256": attr.string(),

        # Attributes for a repository that needs automatic build file generation
        "build_file_name": attr.string(default="BUILD.bazel,BUILD"),
        "build_file_generation": attr.string(default="auto", values=["on", "auto", "off"]),
        "build_tags": attr.string_list(),
    },
)

def env_execute(ctx, arguments, environment = None, **kwargs):
  """env_execute prepends "env -i" to "arguments" before passing it to
  ctx.execute.

  Variables that aren't explicitly mentioned in "environment"
  are removed from the environment. This should be preferred to "ctx.execute"
  in most situations.
  """
  env_args = ["env", "-i"]
  if environment:
    for k, v in environment.items():
      env_args += ["%s=%s" % (k, v)]
  return ctx.execute(env_args + arguments, **kwargs)
