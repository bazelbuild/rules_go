def copy_file_to_rule_name(ctx, src):
    output_file_name = ctx.label.name + (".exe" if ctx.attr.is_windows else "")
    dst = ctx.actions.declare_file(output_file_name)
    ctx.actions.symlink(
        output = dst,
        target_file = src,
        is_executable = True,
    )
    return dst

# Taken from https://github.com/bazelbuild/bazel-skylib/blob/7b859037a673db6f606661323e74c5d4751595e6/rules/private/copy_file_private.bzl
def copy_cmd(ctx, src, dst):
    # Most Windows binaries built with MSVC use a certain argument quoting
    # scheme. Bazel uses that scheme too to quote arguments. However,
    # cmd.exe uses different semantics, so Bazel's quoting is wrong here.
    # To fix that we write the command to a .bat file so no command line
    # quoting or escaping is required.
    bat = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
    ctx.actions.write(
        output = bat,
        # Do not use lib/shell.bzl's shell.quote() method, because that uses
        # Bash quoting syntax, which is different from cmd.exe's syntax.
        content = "@copy /Y \"%s\" \"%s\" >NUL" % (
            src.path.replace("/", "\\"),
            dst.path.replace("/", "\\"),
        ),
        is_executable = True,
    )
    ctx.actions.run(
        inputs = [src],
        tools = [bat],
        outputs = [dst],
        executable = "cmd.exe",
        arguments = ["/C", bat.path.replace("/", "\\")],
        mnemonic = "CopyFile",
        progress_message = "Copying files",
        use_default_shell_env = True,
    )

# Taken from https://github.com/bazelbuild/bazel-skylib/blob/7b859037a673db6f606661323e74c5d4751595e6/rules/private/copy_file_private.bzl
def copy_bash(ctx, src, dst):
    ctx.actions.run_shell(
        tools = [src],
        outputs = [dst],
        command = "cp -f \"$1\" \"$2\"",
        arguments = [src.path, dst.path],
        mnemonic = "CopyFile",
        progress_message = "Copying files",
        use_default_shell_env = True,
    )
