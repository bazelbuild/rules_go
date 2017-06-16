_script_template = """
ANCHOR=$(readlink -f {ANCHOR})
BASE=$(dirname $ANCHOR)
CACHE_FILE=$(realpath {CACHE})
BAZEL_CACHE=$(dirname $CACHE_FILE)
cd {PACKAGE}
bazel {ARGS} {TARGET}
"""

_workspace_template = """
local_repository(name = "io_bazel_rules_go", path = "must be overriden")
load("@io_bazel_rules_go//go:def.bzl", "go_repositories")
go_repositories({GO_VERSION})
"""

_build_args = [
    "--verbose_failures",
    "--sandbox_debug",
    "--spawn_strategy=standalone",
    "--genrule_strategy=standalone",
    "--override_repository", "io_bazel_rules_go=$BASE",
    "--experimental_repository_cache", "$BAZEL_CACHE",
]

_test_args = _build_args + [
    "--test_output=errors",
    "--test_strategy=standalone",
]

def _bazel_test_script_impl(ctx):
  script = ctx.new_file(ctx.label.name+".bash")
  workspace = ctx.new_file("WORKSPACE")
  go_version = ''
  if ctx.attr.go_version:
    go_version = 'go_version = "%s"' % ctx.attr.go_version
  ctx.file_action(output=workspace, content=_workspace_template.format(
    GO_VERSION=go_version,
  ))
  # Build the bazel startup args
  args = []
  if ctx.attr.batch:
    args += ["--batch"]
  # Add the command and any command specific args
  args += [ctx.attr.command]
  if ctx.attr.command == "build":
    args += _build_args
  elif ctx.attr.command == "test":
    args += _test_args
  args += ctx.attr.args

  ctx.file_action(output=script, executable=True, content=_script_template.format(
    ANCHOR = ctx.file.anchor.path,
    CACHE = ctx.file.cache.path,
    PACKAGE = ctx.label.package,
    ARGS = " ".join(args),
    TARGET = ctx.attr.target,
  ))
  return struct(
    files = depset([script]),
    runfiles = ctx.runfiles([workspace])
  )

_bazel_test_script = rule(
    _bazel_test_script_impl,
    attrs = {
        "batch": attr.bool(default=True),
        "command": attr.string(mandatory=True),
        "args": attr.string_list(default=[]),
        "target": attr.string(),
        "anchor": attr.label(allow_files=True, single_file=True),
        "cache": attr.label(allow_files=True, single_file=True),
        "go_version": attr.string(),
    }
)

def bazel_test(name, batch = None, command = None, args=None, target = None, go_version = None, tags=[]):
  script_name = name+"_script"
  anchor = "//:README.md"
  cache = "@rules_go_test_cache//:CACHE"
  _bazel_test_script(
      name = script_name,
      batch = batch,
      command = command,
      args = args,
      target = target,
      anchor = anchor,
      cache = cache,
      go_version = go_version,
  )
  native.sh_test(
      name = name,
      size = "large",
      timeout="short",
      srcs = [script_name],
      tags = ["local", "bazel"] + tags,
      data = native.glob(["**/*"]) + [
        anchor,
        cache,
        "//tests:rules_go_deps",
      ],
  )

def _md5_sum_impl(ctx):
  out = ctx.new_file(ctx.label.name+".md5")
  ctx.action(
    inputs = ctx.files.srcs,
    outputs = [out],
    command = "md5sum " + " ".join([src.path for src in ctx.files.srcs]) + " > " + out.path,
  )
  return struct(files=depset([out]))

md5_sum = rule(
    _md5_sum_impl,
    attrs = { "srcs": attr.label_list(allow_files=True) },
)

def _test_cache_impl(ctx):
  ctx.file("WORKSPACE", """
workspace(name = "%s")
""" % ctx.name)
  ctx.file("BUILD.bazel", """
exports_files(["CACHE"])
""")
  ctx.file("CACHE", "")

_test_cache = repository_rule(
    implementation = _test_cache_impl,
    attrs = {},
)

def test_cache():
  _test_cache(name="rules_go_test_cache")