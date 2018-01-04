
load("@io_bazel_rules_go//go:def.bzl", "go_context")
load("@io_bazel_rules_go//go/private:providers.bzl", _GoPath = "GoPath")


def _swagger_spec_impl(ctx):

    go = go_context(ctx)
    declare_file = go.declare_file
    script_file = declare_file(go, ext=".bash")

    gopath = {}
    files = ctx.files.paths
    for path in ctx.attr.paths:
        entry = path[_GoPath]
        gopath[entry.gopath] = None
    
    ctx.actions.write(output = script_file, is_executable = True, content="""
export GOPATH="{gopath}"
{swagger} generate spec -b {mainpath} -o {out}
""".format(
      swagger = ctx.file._swagger.path,
      mainpath = ctx.attr.mainpath,
      gopath = ":".join(['$(pwd)/{}/{}'.format(ctx.bin_dir.path, entry) for entry in gopath.keys()]),
      out = ctx.outputs.out.path,
))

    ctx.actions.run(
        outputs = [ctx.outputs.out],
        inputs = [script_file] + ctx.files._swagger + files,
        executable = script_file,
        mnemonic = "GenerateSwaggerSpec",
        progress_message = "Generating swagger spec %s" % ctx.outputs.out.short_path,
    )

    return struct(
        files = depset([script_file, ctx.outputs.out]),
        runfiles = ctx.runfiles(files, collect_data = True),
    )


swagger_spec = rule(
    implementation = _swagger_spec_impl,
    attrs = {
        "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_context_data")),
        "_swagger": attr.label(allow_single_file = True, default = Label("@io_bazel_rules_go//third_party/go_swagger"), executable = True, cfg = "host"),
        "mainpath": attr.string(mandatory = True),
        "paths": attr.label_list(mandatory = True, providers = [_GoPath]),
    },
    outputs = {
        "out": "%{name}.json",
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
