load("@io_bazel_rules_go//go/private:go_repository.bzl", "go_repository")

def _bindata_impl(ctx):
  out = ctx.new_file(ctx.label.name + ".go")
  arguments = [
      "-o", out.path,
      "-pkg", ctx.attr.package,
      "-prefix", ctx.label.package,
  ]
  if not ctx.attr.compress:
    arguments += ["-nocompress"]
  if not ctx.attr.metadata:
    arguments += ["-nometadata"]
  ctx.action(
    inputs = ctx.files.srcs,
    outputs = [out],
    executable = ctx.file._bindata,
    arguments = arguments + [src.path for src in ctx.files.srcs],
  )
  return [
    DefaultInfo(
      files = depset([out])
    )
  ]

bindata = rule(
    _bindata_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, cfg = "data"),
        "package": attr.string(mandatory=True),
        "compress": attr.bool(default=True),
        "metadata": attr.bool(default=False),
        "_bindata":  attr.label(allow_files=True, single_file=True, default=Label("@com_github_jteeuwen_go_bindata//go-bindata:go-bindata")),
    },
)
