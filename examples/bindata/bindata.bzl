load("@io_bazel_rules_go//go/private:go_repository.bzl", "go_repository")

def _bindata_impl(ctx):
  out = ctx.new_file(ctx.label.name + ".go")
  ctx.action(
    inputs = ctx.files.srcs,
    outputs = [out],
    executable = ctx.file._bindata,
    arguments = [
        "-o", out.path, 
        "-pkg", ctx.attr.package,
        "-prefix", ctx.label.package,
    ] + [src.path for src in ctx.files.srcs],
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
        "_bindata":  attr.label(allow_files=True, single_file=True, default=Label("@com_github_jteeuwen_go_bindata//go-bindata:go-bindata")),
    },
)

def bindata_repositories():
  go_repository(
      name = "com_github_jteeuwen_go_bindata",
      importpath = "github.com/jteeuwen/go-bindata",
      commit = "a0ff2567cfb70903282db057e799fd826784d41d",
  )
