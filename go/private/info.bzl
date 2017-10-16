def _go_info_script_impl(ctx):
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  script_content = '\n'.join([
    'export GOROOT="{}"'.format(go_toolchain.stdlib.root.path),
    'export GOOS="{}"'.format(go_toolchain.stdlib.goos),
    'export GOARCH="{}"'.format(go_toolchain.stdlib.goarch),
    'export TMP="{}"'.format(go_toolchain.paths.tmp),
    go_toolchain.tools.go.path + " version",
    go_toolchain.tools.go.path + " env",
  ])
  script_file = ctx.new_file(ctx.label.name+".bash")
  ctx.file_action(output=script_file, executable=True, content=script_content)
  return struct(
    files = depset([script_file]),
    runfiles = ctx.runfiles([go_toolchain.tools.go])
  )

_go_info_script = rule(
    _go_info_script_impl,
    attrs = {},
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def go_info():
  _go_info_script(
      name = "go_info_script",
      tags = ["manual"],
  )
  native.sh_binary(
      name = "go_info",
      srcs = ["go_info_script"],
      tags = ["manual"],
  )
