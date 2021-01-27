def _embedsrcs_files_impl(ctx):
    name = ctx.attr.name
    dir = ctx.actions.declare_directory(name)
    args = [dir.path] + ctx.attr.files
    ctx.actions.run(
        outputs = [dir],
        executable = ctx.executable._gen,
        arguments = args,
    )
    return [DefaultInfo(files = depset([dir]))]

embedsrcs_files = rule(
    implementation = _embedsrcs_files_impl,
    attrs = {
        "files": attr.string_list(),
        "_gen": attr.label(
            default = ":gen_embedsrcs_files",
            executable = True,
            cfg = "exec",
        ),
    },
)
