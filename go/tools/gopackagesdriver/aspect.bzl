load(
    "//go/private:providers.bzl",
    "GoArchive",
    "GoStdLib",
)
load(
    "//go/private:context.bzl",
    "go_context",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)

GoPkgInfo = provider()

def _is_file_external(f):
    return f.owner.workspace_root != ""

def _file_path(f):
    if f.is_source and not _is_file_external(f):
        return paths.join("__BAZEL_WORKSPACE__", f.path)
    return paths.join("__BAZEL_EXECROOT__", f.path)

def _go_pkg_info_aspect_impl(target, ctx):
    # Fetch the stdlib JSON file from the inner most target
    stdlib_json = None

    deps_transitive_json = []
    deps_transitive_x = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                deps_transitive_json.append(pkg_info.transitive_json)
                deps_transitive_x.append(pkg_info.transitive_x)
                # Fetch the stdlib json from the first dependency
                if not stdlib_json:
                    stdlib_json = pkg_info.stdlib_json

    # If deps are embedded, do not gather their json or x since they are
    # included in the current target, but do gather their deps'.
    if hasattr(ctx.rule.attr, "embed"):
        for dep in ctx.rule.attr.embed:
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                deps_transitive_json.append(pkg_info.deps_transitive_json)
                deps_transitive_x.append(pkg_info.deps_transitive_x)

    pkg_json = None
    x = None
    if GoArchive in target:
        archive = target[GoArchive]
        x = archive.data.export_file
        pkg = struct(
            ID = str(archive.data.label),
            PkgPath = archive.data.importpath,
            ExportFile = _file_path(archive.data.export_file),
            GoFiles = [
                _file_path(src)
                for src in archive.data.orig_srcs
            ],
            CompiledGoFiles = [
                _file_path(src)
                for src in archive.data.srcs
            ],
        )
        pkg_json = ctx.actions.declare_file(archive.data.name + ".pkg.json")
        ctx.actions.write(pkg_json, content = pkg.to_json())
        # If there was no stdlib json in any dependencies, fetch it from the
        # current go_ node.
        if not stdlib_json:
            stdlib_json = ctx.attr._go_stdlib[GoStdLib].list_json

    pkg_info = GoPkgInfo(
        json = pkg_json,
        stdlib_json = stdlib_json,
        transitive_json = depset(
            direct = [pkg_json] if pkg_json else [],
            transitive = deps_transitive_json,
        ),
        deps_transitive_json = depset(
            transitive = deps_transitive_json,
        ),
        x = x,
        transitive_x = depset(
            direct = [x] if x else None,
            transitive = deps_transitive_x,
        ),
        deps_transitive_x = depset(
            transitive = deps_transitive_x,
        ),
    )

    return [
        pkg_info,
        OutputGroupInfo(
            go_pkg_driver_json = pkg_info.transitive_json,
            go_pkg_driver_x = pkg_info.transitive_x,
            go_pkg_driver_stdlib_json = depset([pkg_info.stdlib_json] if pkg_info.stdlib_json else [])
        ),
    ]

go_pkg_info_aspect = aspect(
    implementation = _go_pkg_info_aspect_impl,
    attr_aspects = ["embed", "deps"],
    attrs = {
        "_go_stdlib": attr.label(
            default = "@io_bazel_rules_go//:stdlib",
        ),
    },
)
