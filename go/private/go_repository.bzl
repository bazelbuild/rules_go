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

load("@io_bazel_rules_go//go/private:common.bzl", "env_execute", "executable_extension")

# We can't disable timeouts on Bazel, but we can set them to large values.
_GO_REPOSITORY_TIMEOUT = 86400

def _go_repository_impl(ctx):
  if ctx.attr.urls:
    # download from explicit source url
    for key in ("commit", "tag", "vcs", "remote"):
      if getattr(ctx.attr, key):
        fail("cannot specifiy both urls and %s" % key, key)
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = ctx.attr.strip_prefix,
        type = ctx.attr.type,
    )
  else:
    # checkout from vcs
    if ctx.attr.commit and ctx.attr.tag:
      fail("cannot specify both of commit and tag", "commit")
    if ctx.attr.commit:
      rev = ctx.attr.commit
      rev_key = "commit"
    elif ctx.attr.tag:
      rev = ctx.attr.tag
      rev_key = "tag"
    else:
      fail("neither commit or tag is specified", "commit")
    for key in ("urls", "strip_prefix", "type", "sha256"):
      if getattr(ctx.attr, key):
        fail("cannot specify both %s and %s" % (rev_key, key), key)

    # Using fetch repo
    if ctx.attr.vcs and not ctx.attr.remote:
      fail("if vcs is specified, remote must also be")

    fetch_repo_env = {
        "PATH": ctx.os.environ["PATH"],  # to find git
    }
    if "SSH_AUTH_SOCK" in ctx.os.environ:
      fetch_repo_env["SSH_AUTH_SOCK"] = ctx.os.environ["SSH_AUTH_SOCK"]
    if "HTTP_PROXY" in ctx.os.environ:
      fetch_repo_env["HTTP_PROXY"] = ctx.os.environ["HTTP_PROXY"]
    if "HTTPS_PROXY" in ctx.os.environ:
      fetch_repo_env["HTTPS_PROXY"] = ctx.os.environ["HTTPS_PROXY"]

    # TODO(yugui): support submodule?
    # c.f. https://www.bazel.io/versions/master/docs/be/workspace.html#git_repository.init_submodules
    _fetch_repo = "@io_bazel_rules_go_repository_tools//:bin/fetch_repo{}".format(executable_extension(ctx))
    args = [
        ctx.path(Label(_fetch_repo)), 
        '--dest', ctx.path(''),
    ]
    if ctx.attr.remote:
        args.extend(['--remote', ctx.attr.remote])
    if rev:
        args.extend(['--rev', rev])
    if ctx.attr.vcs:
        args.extend(['--vcs', ctx.attr.vcs])
    if ctx.attr.importpath:
        args.extend(['--importpath', ctx.attr.importpath])
    result = env_execute(ctx, args, environment = fetch_repo_env, timeout = _GO_REPOSITORY_TIMEOUT)
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
    _gazelle = "@io_bazel_rules_go_repository_tools//:bin/gazelle{}".format(executable_extension(ctx))
    gazelle = ctx.path(Label(_gazelle))
    cmd = [gazelle, '--go_prefix', ctx.attr.importpath, '--mode', 'fix',
            '--repo_root', ctx.path('')]
    if ctx.attr.build_file_name:
      cmd.extend(["--build_file_name", ctx.attr.build_file_name])
    if ctx.attr.build_tags:
      cmd.extend(["--build_tags", ",".join(ctx.attr.build_tags)])
    if ctx.attr.build_external:
      cmd.extend(["--external", ctx.attr.build_external])
    if ctx.attr.build_file_proto_mode:
      cmd.extend(["--proto", ctx.attr.build_file_proto_mode])
    cmd.append(ctx.path(''))
    result = env_execute(ctx, cmd)
    if result.return_code:
      fail("failed to generate BUILD files for %s: %s" % (
          ctx.attr.importpath, result.stderr))

go_repository = repository_rule(
    implementation = _go_repository_impl,
    attrs = {
        # Fundamental attributes of a go repository
        "importpath": attr.string(mandatory = True),

        # Attributes for a repository that should be checked out from VCS
        "commit": attr.string(),
        "tag": attr.string(),
        "vcs": attr.string(
            default = "",
            values = [
                "",
                "git",
                "hg",
                "svn",
                "bzr",
            ],
        ),
        "remote": attr.string(),

        # Attributes for a repository that comes from a source blob not a vcs
        "urls": attr.string_list(),
        "strip_prefix": attr.string(),
        "type": attr.string(),
        "sha256": attr.string(),

        # Attributes for a repository that needs automatic build file generation
        "build_external": attr.string(
            values = [
                "",
                "external",
                "vendored",
            ],
        ),
        "build_file_name": attr.string(default = "BUILD.bazel,BUILD"),
        "build_file_generation": attr.string(
            default = "auto",
            values = [
                "on",
                "auto",
                "off",
            ],
        ),
        "build_tags": attr.string_list(),
        "build_file_proto_mode": attr.string(
            values = [
                "",
                "default",
                "disable",
                "legacy",
            ],
        ),
    },
)
"""See go/workspace.rst#go-repository for full documentation."""
