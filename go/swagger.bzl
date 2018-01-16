
load("@io_bazel_rules_go//go:def.bzl", "go_context")
load("@io_bazel_rules_go//go/private:providers.bzl", _GoPath = "GoPath")


def _collect_gopaths(paths):
    gopath = {}
    for path in paths:
        entry = path[_GoPath]
        gopath[entry.gopath] = None
    return gopath.keys()


def _wrapper_sandwich(go, paths, code):
    return """
#!/bin/sh

set -e

export GOHOSTARCH="{goarch}"
export GOHOSTOS="{goos}"
export GOPATH="{gopath}"
export GOROOT="$(pwd)/{rel_goroot}"
{code}
""".format(
        code = code,
        goarch = go.stdlib.goarch,
        goos = go.stdlib.goos,
        gopath = _go_path_str(go._ctx, _collect_gopaths(paths)),
        rel_goroot = go.stdlib.root_file.dirname,
    )


def _go_path_str(ctx, gopaths):
    """Joins all gopaths into a value for GOPATH variable"""
    return ":".join(['$(pwd)/{}/{}'.format(ctx.bin_dir.path, entry) for entry in gopaths])


def _extract_execution_requirements(tags):
    return {t: "" for t in tags}


def swagger_copy_valid(ctx, paths, script_file, spec_file, out, tags = None):
    go = go_context(ctx)
    content = _wrapper_sandwich(go, paths, """
{swagger} validate {spec_path}
cp {spec_path} {out}
""".format(
      swagger = ctx.file._swagger.path,
      spec_path = spec_file.path,
      out = ctx.outputs.out.path,
    ))
    ctx.actions.write(output = script_file, is_executable = True, content = content)

    if None:
        req = None
    else:
        req = _extract_execution_requirements(tags)

    ctx.actions.run(
        outputs = [out],
        inputs = [
            script_file,
            spec_file,
        ] + ctx.files._swagger + go.sdk_files,
        executable = script_file,
        execution_requirements = req,
        mnemonic = "ValidateSwaggerSpec",
        progress_message = "Validating swagger spec %s" % out.short_path,
    )


def _generate_binary_src_tree(go, paths, script_file, binary_only, scan_models, out):
    ctx = go._ctx

    if binary_only:
        prelude = """
# Generate src tree to enable (binary) pkg
for p in `cat {package_list}`
do
    mkdir -p "{rel_goroot}/src/$p"
    cat <<EOF > "{rel_goroot}/src/$p/binary.go"
//go:binary-only-package

package $(basename $p)
EOF
done
"""
    else:
        prelude = ""

    content = _wrapper_sandwich(go, paths, (prelude + """
{swagger} generate spec -b {base_path} -o {out} {scan_models}
""").format(
      swagger = ctx.file._swagger.path,
      base_path = ctx.attr.base_path,
      out = out.path,
      package_list = go.package_list.path,
      rel_goroot = go.stdlib.root_file.dirname,
      scan_models = "--scan-models" if scan_models else "",
    ))
    ctx.actions.write(output = script_file, is_executable = True, content = content)


def _is_sandboxed(ctx):
    return not ("no-sandbox" in ctx.attr.tags or "local" in ctx.attr.tags)


def swagger_generate_spec(ctx, paths, script_file, out, scan_models=None, tags=None):
    go = go_context(ctx)
    files = []
    sandboxed = _is_sandboxed(ctx)
    if not sandboxed:
        files += go.sdk_files

    _generate_binary_src_tree(go, paths, script_file, sandboxed, scan_models, out)

    go = go_context(ctx)
    
    files += go.stdlib.files
    for f in paths:
        files += f.files.to_list()

    if None:
        req = None
    else:
        req = _extract_execution_requirements(tags)

    ctx.actions.run(
        outputs = [out],
        inputs = [
            go.package_list,
            script_file,
        ] + ctx.files._swagger + files,
        executable = script_file,
        execution_requirements = req,
        mnemonic = "GenerateSwaggerSpec",
        progress_message = "Generating swagger spec %s" % out.short_path,
    )


def _swagger_spec_impl(ctx):

    paths = ctx.attr.paths

    if ctx.attr.validate:
        # Create temporary (unvalidated) spec first
        spec_file = ctx.actions.declare_file("%s.unvalidated" % ctx.outputs.out.basename, sibling = ctx.outputs.out)
    else:
        spec_file = ctx.outputs.out

    generate_file = ctx.actions.declare_file("%s.generate.sh" % ctx.outputs.out.basename, sibling = ctx.outputs.out)
    scan_models = getattr(ctx.attr, "scan_models", default = None)
    swagger_generate_spec(ctx, paths, generate_file, spec_file, scan_models = scan_models, tags = ctx.attr.tags)

    if ctx.attr.validate:
        validate_file = ctx.actions.declare_file("%s.validate.sh" % ctx.outputs.out.basename, sibling = ctx.outputs.out)
        swagger_copy_valid(ctx, paths, validate_file, spec_file, ctx.outputs.out, tags = ctx.attr.tags)

    return struct(
        files = depset([ctx.outputs.out]),
        runfiles = ctx.runfiles([ctx.outputs.out], collect_data = True),
    )


swagger_spec = rule(
    implementation = _swagger_spec_impl,
    attrs = {
        "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_context_data")),
        "_swagger": attr.label(allow_single_file = True, default = Label("@io_bazel_rules_go//third_party/go_swagger"), executable = True, cfg = "host"),
        "base_path": attr.string(mandatory = True),
        "paths": attr.label_list(mandatory = True, providers = [_GoPath]),
        "validate": attr.bool(default = False),
    },
    outputs = {
        "out": "%{name}.json",
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
