# Copyright 2014 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "SHARED_LIB_EXTENSIONS",
    "as_iterable",
    "as_list",
    "as_set",
    "join_srcs",
    "pkg_dir",
    "sets",
    "split_srcs",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "LINKMODE_C_ARCHIVE",
    "LINKMODE_C_SHARED",
)

_CgoCodegen = provider()

# Maximum number of characters in stem of base name for mangled cgo files.
# Some file systems have fairly short limits (eCryptFS has a limit of 143),
# and this should be kept below those to accomodate number suffixes and
# extensions.
MAX_STEM_LENGTH = 130

def _mangle(src, stems):
    """_mangle returns a file stem and extension for a source file that will
    be passed to cgo. The stem will be unique among other sources in the same
    library. It will not contain any separators, so cgo's name mangling algorithm
    will be a no-op."""
    stem, _, ext = src.basename.rpartition(".")
    if len(stem) > MAX_STEM_LENGTH:
        stem = stem[:MAX_STEM_LENGTH]
    if stem in stems:
        for i in range(100):
            next_stem = "{}_{}".format(stem, i)
            if next_stem not in stems:
                break
        if next_stem in stems:
            fail("could not find unique mangled name for {}".format(src.path))
        stem = next_stem
    stems[stem] = True
    return stem, ext

_DEFAULT_PLATFORM_COPTS = select({
    "@io_bazel_rules_go//go/platform:darwin": [],
    "@io_bazel_rules_go//go/platform:windows_amd64": ["-mthreads"],
    "//conditions:default": ["-pthread"],
})

_DEFAULT_PLATFORM_LINKOPTS = select({
    "@io_bazel_rules_go//go/platform:android": ["-llog", "-ldl"],
    "@io_bazel_rules_go//go/platform:darwin": [],
    "@io_bazel_rules_go//go/platform:windows_amd64": ["-mthreads"],
    "//conditions:default": ["-pthread"],
})

def _c_filter_options(options, blacklist):
    return [
        opt
        for opt in options
        if not any([opt.startswith(prefix) for prefix in blacklist])
    ]

def _select_archive(files):
    """Selects a single archive from a list of files produced by a
    static cc_library.

    In some configurations, cc_library can produce multiple files, and the
    order isn't guaranteed, so we can't simply pick the first one.
    """

    # list of file extensions in descending order or preference.
    exts = [".pic.lo", ".lo", ".a"]
    for ext in exts:
        for f in as_iterable(files):
            if f.basename.endswith(ext):
                return f

def _select_archives(libs):
    """Selects a one per item in a cc_library, if needed.

    If no archive can be extracted from all the libraries, this will fail.
    """

    # list of file extensions in descending order or preference.
    outs = []
    for lib in libs:
        archive = _select_archive(lib.files)
        if archive:
            outs.append(archive)
    if not outs:
        fail("cc_library(s) did not produce any files")
    return outs

def _include_unique(opts, flag, include, seen):
    if include in seen:
        return
    seen[include] = True
    opts.extend([flag, include])

def _cgo_codegen_impl(ctx):
    go = go_context(ctx)
    if not go.cgo_tools:
        fail("Go toolchain does not support cgo")
    linkopts = go.cgo_tools.linker_options + ctx.attr.linkopts
    cppopts = go.cgo_tools.compiler_options + ctx.attr.cppopts
    copts = go.cgo_tools.c_options + ctx.attr.copts
    deps = depset([], order = "topological")
    cgo_export_h = go.declare_file(go, path = "_cgo_export.h")
    cgo_export_c = go.declare_file(go, path = "_cgo_export.c")
    cgo_main = go.declare_file(go, path = "_cgo_main.c")
    cgo_types = go.declare_file(go, path = "_cgo_gotypes.go")
    out_dir = cgo_main.dirname

    builder_args = go.args(go)  # interpreted by builder
    tool_args = ctx.actions.args()  # interpreted by cgo
    cc_args = ctx.actions.args()  # interpreted by C compiler

    c_outs = [cgo_export_h, cgo_export_c]
    cxx_outs = [cgo_export_h]
    objc_outs = [cgo_export_h]
    transformed_go_outs = []
    transformed_go_map = {}
    gen_go_outs = [cgo_types]

    seen_includes = {}
    seen_quote_includes = {}
    seen_system_includes = {}

    source = split_srcs(ctx.files.srcs)
    for hdr in source.headers:
        _include_unique(cppopts, "-iquote", hdr.dirname, seen_quote_includes)
    stems = {}
    for src in source.go:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_go_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        gen_c_file = go.declare_file(go, path = mangled_stem + ".cgo2.c")
        transformed_go_outs.append(gen_go_file)
        transformed_go_map[gen_go_file] = src
        c_outs.append(gen_c_file)
        builder_args.add_all(["-src", gen_go_file.path + "=" + src.path])
    for src in source.asm:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        transformed_go_outs.append(gen_file)
        transformed_go_map[gen_go_file] = src
        builder_args.add_all(["-src", gen_file.path + "=" + src.path])
    for src in source.c:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        c_outs.append(gen_file)
        builder_args.add_all(["-src", gen_file.path + "=" + src.path])
    for src in source.cxx:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        cxx_outs.append(gen_file)
        builder_args.add_all(["-src", gen_file.path + "=" + src.path])
    for src in source.objc:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        objc_outs.append(gen_file)
        builder_args.add_all(["-src", gen_file.path + "=" + src.path])

    tool_args.add_all(["-objdir", out_dir])

    inputs = sets.union(ctx.files.srcs, go.crosstool, go.sdk.tools, go.stdlib.libs)
    deps = depset()
    runfiles = ctx.runfiles(collect_data = True)
    for d in ctx.attr.deps:
        runfiles = runfiles.merge(d.data_runfiles)
        if hasattr(d, "cc"):
            inputs = sets.union(inputs, d.cc.transitive_headers)
            deps = sets.union(deps, d.cc.libs)
            cppopts.extend(["-D" + define for define in d.cc.defines])
            for inc in d.cc.include_directories:
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in d.cc.quote_include_directories:
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in d.cc.system_include_directories:
                _include_unique(cppopts, "-isystem", inc, seen_system_includes)
            for lib in as_iterable(d.cc.libs):
                # If both static and dynamic variants are available, Bazel will only give
                # us the static variant. We'll get one file for each transitive dependency,
                # so the same file may appear more than once.
                if (lib.basename.startswith("lib") and
                    any([lib.basename.endswith(ext) for ext in SHARED_LIB_EXTENSIONS])):
                    # If the loader would be able to find the library using rpaths,
                    # use -L and -l instead of hard coding the path to the library in
                    # the binary. This gives users more flexibility. The linker will add
                    # rpaths later. We can't add them here because they are relative to
                    # the binary location, and we don't know where that is.
                    libname = lib.basename[len("lib"):lib.basename.rindex(".")]
                    linkopts.extend(["-L", lib.dirname, "-l", libname])
                else:
                    linkopts.append(lib.path)
            linkopts.extend(d.cc.link_flags)
        elif hasattr(d, "objc"):
            cppopts.extend(["-D" + define for define in d.objc.define.to_list()])
            for inc in d.objc.include:
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in d.objc.iquote:
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in d.objc.include_system:
                _include_unique(cppopts, "-isystem", inc, seen_system_includes)

            # TODO(jayconrod): do we need to link against dynamic libraries or
            # frameworks? We link against *_fully_linked.a, so maybe not?

        else:
            fail("unknown library has neither cc nor objc providers: %s" % d.label)

    # cgo writes CGO_LDFLAGS to _cgo_import.go in the form of pragmas which get
    # compiled into .a files. The linker finds these and passes them to the
    # external linker.
    # TODO(jayconrod): do we need to set this here, or only in _cgo_import?
    # go build does it here.
    env = go.env
    env["CC"] = go.cgo_tools.compiler_executable
    env["CGO_LDFLAGS"] = " ".join(linkopts)

    cc_args.add_all(cppopts)
    cc_args.add_all(copts)

    ctx.actions.run(
        inputs = inputs,
        outputs = c_outs + cxx_outs + objc_outs + gen_go_outs + transformed_go_outs + [cgo_main],
        mnemonic = "CGoCodeGen",
        progress_message = "CGoCodeGen %s" % ctx.label,
        executable = go.builders.cgo,
        arguments = [builder_args, "--", tool_args, "--", cc_args],
        env = env,
    )

    return [
        _CgoCodegen(
            transformed_go = transformed_go_outs,
            transformed_go_map = transformed_go_map,
            gen_go = gen_go_outs,
            deps = as_list(deps),
            exports = [cgo_export_h],
        ),
        DefaultInfo(
            files = depset(),
            runfiles = runfiles,
        ),
        OutputGroupInfo(
            c_files = sets.union(c_outs, source.headers),
            cxx_files = sets.union(cxx_outs, source.headers),
            objc_files = sets.union(objc_outs, source.headers),
            go_files = sets.union(transformed_go_outs, gen_go_outs),
            main_c = as_set([cgo_main]),
        ),
    ]

_cgo_codegen = go_rule(
    _cgo_codegen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(allow_files = False),
        "copts": attr.string_list(),
        "cxxopts": attr.string_list(),
        "cppopts": attr.string_list(),
        "linkopts": attr.string_list(),
        "pure": attr.string(default = "off"),
    },
)

def _cgo_import_impl(ctx):
    go = go_context(ctx)
    out = go.declare_file(go, path = "_cgo_import.go")
    args = go.args(go)
    args.add_all([
        "-import",
        "-src",
        ctx.files.sample_go_srcs[0],
        "--",  # stop builder from processing args
        "-dynout",
        out,
        "-dynimport",
        ctx.file.cgo_o,
    ])
    ctx.actions.run(
        inputs = [
            ctx.file.cgo_o,
            ctx.files.sample_go_srcs[0],
        ] + go.sdk.tools,
        outputs = [out],
        executable = go.builders.cgo,
        arguments = [args],
        mnemonic = "CGoImportGen",
    )
    return struct(
        files = depset([out]),
    )

_cgo_import = go_rule(
    _cgo_import_impl,
    attrs = {
        "cgo_o": attr.label(
            allow_files = True,
            single_file = True,
        ),
        "sample_go_srcs": attr.label_list(allow_files = True),
    },
)
"""Generates symbol-import directives for cgo

Args:
  cgo_o: The loadable object to extract dynamic symbols from.
  sample_go_src: A go source which is compiled together with the generated file.
    The generated file will have the same Go package name as this file.
  out: Destination of the generated codes.
"""

def _pure(ctx, mode):
    return mode.pure

def _not_pure(ctx, mode):
    return not mode.pure

def _cgo_resolve_source(go, attr, source, merge):
    library = source["library"]
    cgo_info = library.cgo_info

    source["orig_srcs"] = cgo_info.orig_srcs
    source["orig_src_map"] = cgo_info.transformed_go_map
    source["runfiles"] = cgo_info.runfiles
    source["cover"] = []
    if source["mode"].pure:
        split = split_srcs(cgo_info.orig_srcs)
        source["srcs"] = split.go + split.asm
        if go.coverage_instrumented:
            source["cover"] = source["srcs"]
    else:
        source["srcs"] = cgo_info.transformed_go_srcs + cgo_info.gen_go_srcs
        if go.coverage_instrumented:
            source["cover"] = cgo_info.transformed_go_srcs
        source["cgo_deps"] = cgo_info.cgo_deps
        source["cgo_exports"] = cgo_info.cgo_exports
        source["cgo_archives"] = cgo_info.cgo_archives

def _cgo_collect_info_impl(ctx):
    go = go_context(ctx)
    codegen = ctx.attr.codegen[_CgoCodegen]
    import_files = as_list(ctx.files.cgo_import)
    runfiles = ctx.runfiles(collect_data = True)
    runfiles = runfiles.merge(ctx.attr.codegen.data_runfiles)

    library = go.new_library(
        go,
        resolver = _cgo_resolve_source,
        cgo_info = struct(
            orig_srcs = ctx.files.srcs,
            transformed_go_srcs = codegen.transformed_go,
            transformed_go_map = codegen.transformed_go_map,
            gen_go_srcs = codegen.gen_go + import_files,
            cgo_deps = codegen.deps,
            cgo_exports = codegen.exports,
            cgo_archives = _select_archives(ctx.attr.libs),
            runfiles = runfiles,
        ),
    )
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())

    return [
        source,
        library,
        DefaultInfo(files = depset(), runfiles = runfiles),
    ]

_cgo_collect_info = go_rule(
    _cgo_collect_info_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "codegen": attr.label(
            mandatory = True,
            providers = [_CgoCodegen],
        ),
        "libs": attr.label_list(
            mandatory = True,
            allow_files = True,
            providers = ["cc"],
        ),
        "cgo_import": attr.label(mandatory = True),
    },
)
"""No-op rule that collects information from _cgo_codegen and cc_library
info into a GoSourceList provider for easy consumption."""

def setup_cgo_library(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, **common_attrs):
    # Apply build constraints to source files (both Go and C) but not to header
    # files. Separate filtered Go and C sources.

    # Run cgo on the filtered Go files. This will split them into pure Go files
    # and pure C files, plus a few other glue files.
    repo_name = native.repository_name()
    base_dir = pkg_dir(
        "external/" + repo_name[1:] if len(repo_name) > 1 else "",
        native.package_name(),
    )
    copts = copts
    cxxopts = cxxopts
    cppopts = cppopts + ["-I", base_dir]

    if objc:
        clinkopts = clinkopts + [
            "-fobjc-link-runtime",
        ]
        for framework in objcopts.get("sdk_frameworks", []):
            clinkopts.append("-framework %s" % framework)

    cgo_codegen_name = name + ".cgo_codegen"
    _cgo_codegen(
        name = cgo_codegen_name,
        srcs = srcs,
        deps = cdeps,
        copts = copts,
        cxxopts = cxxopts,
        cppopts = cppopts,
        linkopts = clinkopts,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_go_files = name + ".select_go_files"
    native.filegroup(
        name = select_go_files,
        srcs = [cgo_codegen_name],
        output_group = "go_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_c_files = name + ".select_c_files"
    native.filegroup(
        name = select_c_files,
        srcs = [cgo_codegen_name],
        output_group = "c_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_cxx_files = name + ".select_cxx_files"
    native.filegroup(
        name = select_cxx_files,
        srcs = [cgo_codegen_name],
        output_group = "cxx_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_objc_files = name + ".select_objc_files"
    native.filegroup(
        name = select_objc_files,
        srcs = [cgo_codegen_name],
        output_group = "objc_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_main_c = name + ".select_main_c"
    native.filegroup(
        name = select_main_c,
        srcs = [cgo_codegen_name],
        output_group = "main_c",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    # Compile C sources and generated files into a library. This will be linked
    # into binaries that depend on this cgo_library. It will also be used
    # in _cgo_.o.
    platform_copts = _DEFAULT_PLATFORM_COPTS
    platform_linkopts = _DEFAULT_PLATFORM_LINKOPTS

    cgo_c_lib_name = name + ".cgo_c_lib"
    native.cc_library(
        name = cgo_c_lib_name,
        srcs = [select_c_files],
        deps = cdeps,
        copts = copts + cppopts + platform_copts + [
            # The generated thunks often contain unused variables.
            "-Wno-unused-variable",
        ],
        linkopts = clinkopts + platform_linkopts,
        linkstatic = 1,
        # _cgo_.o needs all symbols because _cgo_import needs to see them.
        alwayslink = 1,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    cgo_cxx_lib_name = name + ".cgo_cxx_lib"
    native.cc_library(
        name = cgo_cxx_lib_name,
        srcs = [select_cxx_files],
        deps = cdeps,
        copts = cxxopts + cppopts + platform_copts + [
            # The generated thunks often contain unused variables.
            "-Wno-unused-variable",
        ],
        linkopts = clinkopts + platform_linkopts,
        linkstatic = 1,
        # _cgo_.o needs all symbols because _cgo_import needs to see them.
        alwayslink = 1,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    cgo_o_deps = [
        cgo_c_lib_name,
        cgo_cxx_lib_name,
    ]
    cgo_collect_info_libs = cgo_o_deps[:]

    if objc:
        cgo_objc_lib_name = name + ".cgo_objc_lib"
        objcopts.update(common_attrs)
        native.objc_library(
            name = cgo_objc_lib_name,
            srcs = [select_objc_files],
            deps = cdeps,
            copts = copts + cppopts + platform_copts + [
                # The generated thunks often contain unused variables.
                "-Wno-unused-variable",
            ],
            # _cgo_.o needs all symbols because _cgo_import needs to see them.
            alwayslink = 1,
            visibility = ["//visibility:private"],
            **objcopts
        )
        cgo_o_deps.append(cgo_objc_lib_name)

        # cgo needs all the symbols it can find when generating _cgo_import.go. For
        # cc_library we use linkstatic = 1. This option does not exist on
        # objc_library. To work around that, we used the implicit and documented
        # target that objc_library provides, which includes the fully transitive
        # dependencies.
        # See https://docs.bazel.build/versions/master/be/objective-c.html#objc_library
        # for more information.
        cgo_collect_info_libs.append(cgo_objc_lib_name + "_fully_linked.a")

    # Create a loadable object with no undefined references. cgo reads this
    # when it generates _cgo_import.go.
    cgo_o_name = name + "._cgo_.o"
    native.cc_binary(
        name = cgo_o_name,
        srcs = [select_main_c],
        deps = cdeps + cgo_o_deps,
        copts = copts + cppopts,
        linkopts = clinkopts,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    # Create a Go file which imports symbols from the C library.
    cgo_import_name = name + ".cgo_import"
    _cgo_import(
        name = cgo_import_name,
        cgo_o = cgo_o_name,
        sample_go_srcs = [select_go_files],
        visibility = ["//visibility:private"],
        **common_attrs
    )

    cgo_embed_name = name + ".cgo_embed"
    _cgo_collect_info(
        name = cgo_embed_name,
        srcs = srcs,
        codegen = cgo_codegen_name,
        libs = cgo_collect_info_libs,
        cgo_import = cgo_import_name,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    return cgo_embed_name

# Sets up the cc_ targets when a go_binary is built in either c-archive or
# c-shared mode.
def go_binary_c_archive_shared(name, kwargs):
    linkmode = kwargs.get("linkmode")
    if linkmode not in [LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE]:
        return
    cgo_exports = name + ".cgo_exports"
    c_hdrs = name + ".c_hdrs"
    cc_import_name = name + ".cc_import"
    cc_library_name = name + ".cc"
    tags = kwargs.get("tags", ["manual"])
    if "manual" not in tags:
        # These archives can't be built on all platforms, so use "manual" tag.s
        tags.append("manual")
    native.filegroup(
        name = cgo_exports,
        srcs = [name],
        output_group = "cgo_exports",
        visibility = ["//visibility:private"],
        tags = tags,
    )
    native.genrule(
        name = c_hdrs,
        srcs = [cgo_exports],
        outs = ["%s.h" % name],
        cmd = "cat $(SRCS) > $(@)",
        visibility = ["//visibility:private"],
        tags = tags,
    )
    cc_import_kwargs = {}
    if linkmode == LINKMODE_C_SHARED:
        cc_import_kwargs["shared_library"] = name
    elif linkmode == LINKMODE_C_ARCHIVE:
        cc_import_kwargs["static_library"] = name
    native.cc_import(
        name = cc_import_name,
        alwayslink = 1,
        visibility = ["//visibility:private"],
        tags = tags,
        **cc_import_kwargs
    )
    native.cc_library(
        name = cc_library_name,
        hdrs = [c_hdrs],
        deps = [cc_import_name],
        alwayslink = 1,
        linkstatic = (linkmode == LINKMODE_C_ARCHIVE and 1 or 0),
        copts = _DEFAULT_PLATFORM_COPTS,
        linkopts = _DEFAULT_PLATFORM_COPTS,
        visibility = ["//visibility:public"],
        tags = tags,
    )
