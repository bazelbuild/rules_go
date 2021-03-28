load("//go:def.bzl", "GoArchive")
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
    pkg_json = None
    x = None
    if GoArchive in target:
        archive = target[GoArchive]
        x = archive.data.export_file
        pkg = struct(
            ID = str(archive.data.label),
            Name = "main" if archive.source.library.is_main else paths.basename(archive.data.importpath),
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

    deps_transitive_json = []
    deps_transitive_x = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                deps_transitive_json.append(pkg_info.transitive_json)
                deps_transitive_x.append(pkg_info.transitive_x)
    # If deps are embedded, no not gather their json or x since they are
    # included in the current target, but do gather their deps'.
    if hasattr(ctx.rule.attr, "embed"):
        for dep in ctx.rule.attr.embed:
            if GoPkgInfo in dep:
                pkg_info = dep[GoPkgInfo]
                deps_transitive_json.append(pkg_info.deps_transitive_json)
                deps_transitive_x.append(pkg_info.deps_transitive_x)

    pkg_info = GoPkgInfo(
        json = pkg_json,
        transitive_json = depset(
            direct = [pkg_json] if pkg_json else None,
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
        )
    ]

go_pkg_info_aspect = aspect(
    implementation = _go_pkg_info_aspect_impl,
    attr_aspects = ["embed", "deps"],
)

def _go_std_pkg_info_aspect_impl(target, ctx):
    go = go_context(ctx, attr = ctx.rule.attr)
    return [
        OutputGroupInfo(
            go_pkg_driver_stdlib_json = [go.stdlib.list_json],
        ),
    ]

go_std_pkg_info_aspect = aspect(
    implementation = _go_std_pkg_info_aspect_impl,
    attrs = {
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
