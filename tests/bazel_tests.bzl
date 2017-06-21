_build_args = [
    "--fetch=False",
    "--verbose_failures",
    "--sandbox_debug",
    "--spawn_strategy=standalone",
    "--genrule_strategy=standalone",
]

_test_args = _build_args + [
    "--test_output=errors",
    "--test_strategy=standalone",
]

_coverage_args = _test_args

def _bazel_test_script_impl(ctx):
  script_file = ctx.new_file(ctx.label.name+".bash")
  script_content = ''
  workspace_file = ctx.new_file("WORKSPACE")
  workspace_content = ''
  go_version = ''
  if ctx.attr.go_version:
    go_version = 'go_version = "%s"' % ctx.attr.go_version
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
  elif ctx.attr.command == "coverage":
    args += _coverage_args

  for ext in ctx.files.externals:
    root = ext.owner.workspace_root
    _,_,ws = root.rpartition("/")
    workspace_content += 'local_repository(name = "{0}", path = "{1}/{2}")\n'.format(ws, ctx.attr._execroot.path, root)
  workspace_content += 'local_repository(name = "{0}", path = "{1}")\n'.format(ctx.attr._go_toolchain.sdk, ctx.attr._go_toolchain.root.path)
  # finalise the workspace file
  workspace_content += 'load("@io_bazel_rules_go//go:def.bzl", "go_repositories")\n'
  workspace_content += 'go_repositories({0})\n'.format(go_version)
  ctx.file_action(output=workspace_file, content=workspace_content)
  # finalise the script
  args += ctx.attr.args + [ctx.attr.target]
  script_content += 'cd {0}\n'.format(ctx.label.package)
  script_content += 'bazel {0}\n'.format(" ".join(args))
  ctx.file_action(output=script_file, executable=True, content=script_content)
  return struct(
    files = depset([script_file]),
    runfiles = ctx.runfiles([workspace_file])
  )

_bazel_test_script = rule(
    _bazel_test_script_impl,
    attrs = {
        "batch": attr.bool(default=True),
        "command": attr.string(mandatory=True, values=["build", "test", "coverage"]),
        "args": attr.string_list(default=[]),
        "target": attr.string(mandatory=True),
        "externals": attr.label_list(allow_files=True),
        "go_version": attr.string(),
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
        "_execroot": attr.label(default = Label("@test_environment//:execroot")),
    }
)

def bazel_test(name, batch = None, command = None, args=None, target = None, go_version = None, tags=[]):
  script_name = name+"_script"
  externals = [
      "@io_bazel_rules_go//:README.md",
      "@local_config_cc//:cc_wrapper",
      "@io_bazel_rules_go_toolchain//:BUILD.bazel",
  ]
  _bazel_test_script(
      name = script_name,
      batch = batch,
      command = command,
      args = args,
      target = target,
      externals = externals,
      go_version = go_version,
  )
  native.sh_test(
      name = name,
      size = "large",
      timeout = "short",
      srcs = [script_name],
      tags = ["local", "bazel"] + tags,
      data = native.glob(["**/*"]) + externals + [
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

def _test_environment_impl(ctx):
  execroot, _, ws = str(ctx.path(".")).rpartition("/external/")
  if not ctx.name == ws:
    fail("workspace did not match, expected:", ctx.name, "got:", ws)
  ctx.file("WORKSPACE", """
workspace(name = "%s")
""" % ctx.name)
  ctx.file("BUILD.bazel", """
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "execroot")
execroot(
    name = "execroot",
    path = "{0}",
    visibility = ["//visibility:public"],
)
""".format(execroot))

_test_environment = repository_rule(
    implementation = _test_environment_impl,
    attrs = {},
)

def test_environment():
  _test_environment(name="test_environment")

def _execroot_impl(ctx):
  return struct(path = ctx.attr.path)

execroot = rule(
    _execroot_impl, 
    attrs = {
        "path": attr.string(mandatory = True),
    }
)