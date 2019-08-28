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
    "@bazel_skylib//lib:old_sets.bzl",
    "sets",
)
load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "as_iterable",
    "as_list",
    "as_set",
    "has_simple_shared_lib_extension",
    "has_versioned_shared_lib_extension",
    "join_srcs",
    "pkg_dir",
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
    "LINKMODE_NORMAL",
    "LINKMODE_PIE",
    "extldflags_from_cc_toolchain",
    "mode_string",
    "new_mode",
)
load(
    "@io_bazel_rules_go//go/platform:list.bzl",
    "GOARCH",
    "GOOS",
    "GOOS_GOARCH",
    "MSAN_GOOS_GOARCH",
    "RACE_GOOS_GOARCH",
)
load(
    "@io_bazel_rules_go_compat//:compat.bzl",
    "CC_PROVIDER_NAME",
    "cc_compile_flags",
    "cc_defines",
    "cc_includes",
    "cc_libs",
    "cc_link_flags",
    "cc_quote_includes",
    "cc_system_includes",
    "cc_transitive_headers",
    "has_cc",
)

def cgo_configure(go, srcs, cdeps, cppopts, copts, cxxopts, clinkopts):
    """cgo_configure returns the inputs and compile / link options
    that are required to build a cgo archive.

    Args:
        go: a GoContext.
        srcs: list of source files being compiled. Include options are added
            for the headers.
        cdeps: list of Targets for C++ dependencies. Include and link options
            may be added.
        cppopts: list of C preprocessor options for the library.
        copts: list of C compiler options for the library.
        cxxopts: list of C++ compiler options for the library.
        clinkopts: list of linker options for the library.

    Returns: a struct containing:
        inputs: depset of files that must be available for the build.
        deps: depset of files for dynamic libraries.
        runfiles: runfiles object for the C/C++ dependencies.
        cppopts: complete list of preprocessor options
        copts: complete list of C compiler options.
        cxxopts: complete list of C++ compiler options.
        objcopts: complete list of Objective-C compiler options.
        objcxxopts: complete list of Objective-C++ compiler options.
        clinkopts: complete list of linker options.
    """
    if not go.cgo_tools:
        fail("Go toolchain does not support cgo")

    cppopts = list(cppopts)
    base_dir, _, _ = go._ctx.build_file_path.rpartition("/")
    if base_dir:
        cppopts.extend(["-I", base_dir])
    copts = go.cgo_tools.c_compile_options + copts
    cxxopts = go.cgo_tools.cxx_compile_options + cxxopts
    objcopts = go.cgo_tools.objc_compile_options + copts
    objcxxopts = go.cgo_tools.objcxx_compile_options + cxxopts
    clinkopts = extldflags_from_cc_toolchain(go) + clinkopts
    if go.mode != LINKMODE_NORMAL:
        for opt_list in (copts, cxxopts, objcopts, objcxxopts):
            if "-fPIC" not in opt_list:
                opt_list.append("-fPIC")

    seen_includes = {}
    seen_quote_includes = {}
    seen_system_includes = {}
    for f in srcs:
        if f.basename.endswith(".h"):
            _include_unique(cppopts, "-iquote", f.dirname, seen_quote_includes)

    inputs_direct = []
    inputs_transitive = []
    deps_direct = []
    lib_opts = []
    runfiles = go._ctx.runfiles(collect_data = True)
    for d in cdeps:
        runfiles = runfiles.merge(d.data_runfiles)
        if has_cc(d):
            inputs_transitive.append(cc_transitive_headers(d))
            inputs_direct.extend(cc_libs(d))
            deps_direct.extend(cc_libs(d))
            cppopts.extend(["-D" + define for define in cc_defines(d)])
            for inc in cc_includes(d):
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in cc_quote_includes(d):
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in cc_system_includes(d):
                _include_unique(cppopts, "-isystem", inc, seen_system_includes)
            for lib in cc_libs(d):
                # If both static and dynamic variants are available, Bazel will only give
                # us the static variant. We'll get one file for each transitive dependency,
                # so the same file may appear more than once.
                if (lib.basename.startswith("lib") and
                    has_simple_shared_lib_extension(lib.basename)):
                    # If the loader would be able to find the library using rpaths,
                    # use -L and -l instead of hard coding the path to the library in
                    # the binary. This gives users more flexibility. The linker will add
                    # rpaths later. We can't add them here because they are relative to
                    # the binary location, and we don't know where that is.
                    libname = lib.basename[len("lib"):lib.basename.rindex(".")]
                    clinkopts.extend(["-L", lib.dirname, "-l", libname])
                    inputs_direct.append(lib)
                elif (lib.basename.startswith("lib") and
                      has_versioned_shared_lib_extension(lib.basename)):
                    # With a versioned shared library, we must use the full filename,
                    # otherwise the library will not be found by the linker.
                    libname = ":%s" % lib.basename
                    clinkopts.extend(["-L", lib.dirname, "-l", libname])
                    inputs_direct.append(lib)
                else:
                    lib_opts.append(lib.path)
            clinkopts.extend(cc_link_flags(d))

        elif hasattr(d, "objc"):
            cppopts.extend(["-D" + define for define in d.objc.define.to_list()])
            for inc in d.objc.include.to_list():
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in d.objc.iquote.to_list():
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in d.objc.include_system.to_list():
                _include_unique(cppopts, "-isystem", inc, seen_system_includes)

            # TODO(jayconrod): do we need to link against dynamic libraries or
            # frameworks? We link against *_fully_linked.a, so maybe not?

        else:
            fail("unknown library has neither cc nor objc providers: %s" % d.label)

    inputs = depset(direct = inputs_direct, transitive = inputs_transitive)
    deps = depset(direct = deps_direct)

    # HACK: some C/C++ toolchains will ignore libraries (including dynamic libs
    # specified with -l flags) unless they appear after .o or .a files with
    # undefined symbols they provide. Put all the .a files from cdeps first,
    # so that we actually link with -lstdc++ and others.
    clinkopts = lib_opts + clinkopts

    return struct(
        inputs = inputs,
        deps = deps,
        runfiles = runfiles,
        cppopts = cppopts,
        copts = copts,
        cxxopts = cxxopts,
        objcopts = objcopts,
        objcxxopts = objcxxopts,
        clinkopts = clinkopts,
    )

_CgoCodegen = provider()
_CgoInfo = provider()

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

def _select_archives(libs):
    """Selects static archives to pack from a list of cc_library targets.
    Returns at most one file per library.

    Each cc_library may produce several files which are logically the same
    static library. We prefer files with the extensions .pic.lo, .lo, or .a
    in that order. If a cc_library is empty, it may not produce any files,
    so _select_archives may return fewer archives than libs.
    """

    # list of file extensions in descending order or preference.
    exts = [".pic.lo", ".lo", ".a"]
    outs = []
    for lib in libs:
        out = None
        for ext in exts:
            for f in as_iterable(lib.files):
                if f.basename.endswith(ext):
                    out = f
                    break
            if out:
                break
        if out:
            outs.append(out)
    return outs

def _include_unique(opts, flag, include, seen):
    if include in seen:
        return
    seen[include] = True
    opts.extend([flag, include])

def _encode_cgo_mode(goos, goarch, race, msan):
    return "_".join((goos, goarch, str(race), str(msan)))

def _cgo_codegen_impl(ctx):
    go = go_context(ctx)
    if not go.cgo_tools:
        fail("Go toolchain does not support cgo")
    linkopts = extldflags_from_cc_toolchain(go) + ctx.attr.linkopts
    cppopts = list(ctx.attr.cppopts)
    copts = go.cgo_tools.c_compile_options + ctx.attr.copts
    deps = depset([], order = "topological")
    cgo_export_h = go.declare_file(go, path = "_cgo_export.h")
    cgo_export_c = go.declare_file(go, path = "_cgo_export.c")
    cgo_main = go.declare_file(go, path = "_cgo_main.c")
    cgo_types = go.declare_file(go, path = "_cgo_gotypes.go")
    out_dir = cgo_main.dirname

    builder_args = go.builder_args(go, "cgo")  # interpreted by builder
    tool_args = go.tool_args(go)  # interpreted by cgo
    cc_args = go.tool_args(go)  # interpreted by C compiler

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
        builder_args.add("-src", gen_go_file.path + "=" + src.path)
    for src in source.asm:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        transformed_go_outs.append(gen_file)
        builder_args.add("-src", gen_file.path + "=" + src.path)
    for src in source.c:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        c_outs.append(gen_file)
        builder_args.add("-src", gen_file.path + "=" + src.path)
    for src in source.cxx:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        cxx_outs.append(gen_file)
        builder_args.add("-src", gen_file.path + "=" + src.path)
    for src in source.objc:
        mangled_stem, src_ext = _mangle(src, stems)
        gen_file = go.declare_file(go, path = mangled_stem + ".cgo1." + src_ext)
        objc_outs.append(gen_file)
        builder_args.add("-src", gen_file.path + "=" + src.path)

    # Filter out -lstdc++ in CGO_LDFLAGS if we don't have any C++ code. This
    # also gets filtered out in link.bzl.
    have_cc = len(source.cxx) + len(source.objc) + len(ctx.attr.deps) > 0
    if not have_cc:
        linkopts = [o for o in linkopts if o not in ("-lstdc++", "-lc++")]

    tool_args.add("-objdir", out_dir)

    inputs = sets.union(ctx.files.srcs, go.crosstool, go.sdk.tools)
    deps = depset()
    runfiles = ctx.runfiles(collect_data = True)
    for d in ctx.attr.deps:
        runfiles = runfiles.merge(d.data_runfiles)
        if has_cc(d):
            inputs = sets.union(inputs, cc_transitive_headers(d))
            deps = sets.union(deps, cc_libs(d))
            cppopts.extend(["-D" + define for define in cc_defines(d)])
            for inc in cc_includes(d):
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in cc_quote_includes(d):
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in cc_system_includes(d):
                _include_unique(cppopts, "-isystem", inc, seen_system_includes)
            for lib in cc_libs(d):
                # If both static and dynamic variants are available, Bazel will only give
                # us the static variant. We'll get one file for each transitive dependency,
                # so the same file may appear more than once.
                if (lib.basename.startswith("lib") and
                    has_simple_shared_lib_extension(lib.basename)):
                    # If the loader would be able to find the library using rpaths,
                    # use -L and -l instead of hard coding the path to the library in
                    # the binary. This gives users more flexibility. The linker will add
                    # rpaths later. We can't add them here because they are relative to
                    # the binary location, and we don't know where that is.
                    libname = lib.basename[len("lib"):lib.basename.rindex(".")]
                    linkopts.extend(["-L", lib.dirname, "-l", libname])
                elif (lib.basename.startswith("lib") and
                      has_versioned_shared_lib_extension(lib.basename)):
                    # With a versioned shared library, we must use the full filename,
                    # otherwise the library will not be found by the linker.
                    libname = ":%s" % lib.basename
                    linkopts.extend(["-L", lib.dirname, "-l", libname])
                else:
                    linkopts.append(lib.path)
            linkopts.extend(cc_link_flags(d))
        elif hasattr(d, "objc"):
            cppopts.extend(["-D" + define for define in d.objc.define.to_list()])
            for inc in d.objc.include.to_list():
                _include_unique(cppopts, "-I", inc, seen_includes)
            for inc in d.objc.iquote.to_list():
                _include_unique(cppopts, "-iquote", inc, seen_quote_includes)
            for inc in d.objc.include_system.to_list():
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
    env["CC"] = go.cgo_tools.c_compiler_path
    env["CGO_LDFLAGS"] = " ".join(linkopts)

    cc_args.add_all(cppopts)
    cc_args.add_all(copts)

    ctx.actions.run(
        inputs = inputs,
        outputs = c_outs + cxx_outs + objc_outs + gen_go_outs + transformed_go_outs + [cgo_main],
        mnemonic = "CGoCodeGen",
        progress_message = "CGoCodeGen %s" % ctx.label,
        executable = go.toolchain._builder,
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
        # Attributes below are read into go.mode. They determine build tags
        # which are used to filter sources. We need to set these explicitly,
        # since the aspect won't reach this rule.
        "goos": attr.string(
            mandatory = True,
            values = GOOS.keys(),
        ),
        "goarch": attr.string(
            mandatory = True,
            values = GOARCH.keys(),
        ),
        "race": attr.string(
            values = ["on", "off"],
            default = "off",
        ),
        "msan": attr.string(
            values = ["on", "off"],
            default = "off",
        ),
        "pure": attr.string(default = "off"),  # never explicitly set
    },
)

def _cgo_import_impl(ctx):
    go = go_context(ctx)
    out = go.declare_file(go, path = "_cgo_import.go")
    args = go.builder_args(go, "cgo")
    args.add("-import")
    args.add("-src", ctx.files.sample_go_srcs[0])
    args.add("--")  # stop builder from processing args
    args.add("-dynout", out)
    args.add("-dynimport", ctx.file.cgo_o)
    ctx.actions.run(
        inputs = [
            ctx.file.cgo_o,
            ctx.files.sample_go_srcs[0],
        ] + go.sdk.tools,
        outputs = [out],
        executable = go.toolchain._builder,
        arguments = [args],
        mnemonic = "CGoImportGen",
    )
    return [DefaultInfo(files = depset([out]))]

_cgo_import = go_rule(
    _cgo_import_impl,
    attrs = {
        "cgo_o": attr.label(
            allow_single_file = True,
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

def _cgo_resolve_source(go, attr, source, merge):
    library = source["library"]
    cgo_mode = _encode_cgo_mode(go.mode.goos, go.mode.goarch, go.mode.race, go.mode.msan)
    cgo_info = None
    for target, target_cgo_mode in library.cgo_mode_info.items():
        if cgo_mode == target_cgo_mode:
            cgo_info = target[_CgoInfo]
            break
    if not cgo_info:
        fail("{}: no matching cgo rules for mode {}".format(library.label, mode_string(go.mode)))

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
    return [
        _CgoInfo(
            orig_srcs = ctx.files.srcs,
            transformed_go_srcs = codegen.transformed_go,
            transformed_go_map = codegen.transformed_go_map,
            gen_go_srcs = codegen.gen_go + import_files,
            cgo_deps = codegen.deps,
            cgo_exports = codegen.exports,
            cgo_archives = _select_archives(ctx.attr.libs),
            runfiles = runfiles,
        ),
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
            providers = [CC_PROVIDER_NAME],
        ),
        "cgo_import": attr.label(mandatory = True),
    },
)
"""No-op rule that collects mode-specific information from _cgo_codegen and
cc_library info into a _CgoInfo provider for easy consumption."""

def _cgo_select_embed_impl(ctx):
    go = go_context(ctx)
    library = go.new_library(
        go,
        resolver = _cgo_resolve_source,
        cgo_mode_info = ctx.attr.info,
    )
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())
    return [
        library,
        source,
        DefaultInfo(files = depset(), runfiles = source.runfiles),
    ]

_cgo_select_embed = go_rule(
    _cgo_select_embed_impl,
    attrs = {
        "info": attr.label_keyed_string_dict(
            mandatory = True,
            providers = [_CgoInfo],
        ),
    },
)
"""No-op rule that collects information about cgo rules in all supported
modes, then builds GoLibrary and GoSource providers for the current mode."""

def setup_cgo_library(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, linkmode, **common_attrs):
    """Declares a graph of rules needed to build the cgo part of a go_library.
    The graph is collected into a single rule which may be embedded in a
    regular go_library.

    We build C/C++/ObjC code using cc_library / objc_library rules. We'd prefer
    to create our own compile / link actions within a single rule, but we'd
    almost certainly break something.
    """

    # Add some implicit flags for the current rule.
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
    if linkmode == LINKMODE_PIE and "-pie" not in clinkopts:
        clinkopts = clinkopts + ["-pie"]

    # Declare cgo rules for each platform and race / msan configuration. We
    # normally propagate mode attributes through an aspect, but we can't create
    # alternate cc_library rules with an aspect.
    cgo_mode_info = {}
    for goos, goarch in GOOS_GOARCH:
        cgo_info_name = setup_cgo_library_for_mode(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, goos, goarch, race = False, msan = False, **common_attrs)
        cgo_mode_info[cgo_info_name] = _encode_cgo_mode(goos, goarch, race = False, msan = False)
    for goos, goarch in RACE_GOOS_GOARCH:
        cgo_info_name = setup_cgo_library_for_mode(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, goos, goarch, race = True, msan = False, **common_attrs)
        cgo_mode_info[cgo_info_name] = _encode_cgo_mode(goos, goarch, race = True, msan = False)
    for goos, goarch in MSAN_GOOS_GOARCH:
        cgo_info_name = setup_cgo_library_for_mode(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, goos, goarch, race = False, msan = True, **common_attrs)
        cgo_mode_info[cgo_info_name] = _encode_cgo_mode(goos, goarch, race = False, msan = True)

    # Collect everything in a single embedable, aspect-friendly library.
    cgo_embed_name = name + "__cgo_embed"
    _cgo_select_embed(
        name = cgo_embed_name,
        info = cgo_mode_info,
        visibility = ["//visibility:private"],
        **common_attrs
    )
    return cgo_embed_name

def setup_cgo_library_for_mode(name, srcs, cdeps, copts, cxxopts, cppopts, clinkopts, objc, objcopts, goos, goarch, race, msan, **common_attrs):
    mode = new_mode(
        goos = goos,
        goarch = goarch,
        race = race,
        msan = msan,
    )
    prefix = "{}%{}%".format(name, mode_string(mode))
    cgo_codegen_name = prefix + "cgo_codegen"
    _cgo_codegen(
        name = cgo_codegen_name,
        srcs = srcs,
        deps = cdeps,
        copts = copts,
        cxxopts = cxxopts,
        cppopts = cppopts,
        linkopts = clinkopts,
        goos = goos,
        goarch = goarch,
        race = "on" if race else "off",
        msan = "on" if msan else "off",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_go_files = prefix + "select_go_files"
    native.filegroup(
        name = select_go_files,
        srcs = [cgo_codegen_name],
        output_group = "go_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_c_files = prefix + "select_c_files"
    native.filegroup(
        name = select_c_files,
        srcs = [cgo_codegen_name],
        output_group = "c_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_cxx_files = prefix + "select_cxx_files"
    native.filegroup(
        name = select_cxx_files,
        srcs = [cgo_codegen_name],
        output_group = "cxx_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_objc_files = prefix + "select_objc_files"
    native.filegroup(
        name = select_objc_files,
        srcs = [cgo_codegen_name],
        output_group = "objc_files",
        visibility = ["//visibility:private"],
        **common_attrs
    )

    select_main_c = prefix + "select_main_c"
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
    cgo_c_lib_name = prefix + "cgo_c_lib"
    native.cc_library(
        name = cgo_c_lib_name,
        srcs = [select_c_files],
        deps = cdeps,
        copts = copts + cppopts + _DEFAULT_PLATFORM_COPTS + [
            # The generated thunks often contain unused variables.
            "-Wno-unused-variable",
        ],
        linkopts = clinkopts + _DEFAULT_PLATFORM_LINKOPTS,
        linkstatic = 1,
        # _cgo_.o needs all symbols because _cgo_import needs to see them.
        alwayslink = 1,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    cgo_cxx_lib_name = prefix + "cgo_cxx_lib"
    native.cc_library(
        name = cgo_cxx_lib_name,
        srcs = [select_cxx_files],
        deps = cdeps,
        copts = cxxopts + cppopts + _DEFAULT_PLATFORM_COPTS + [
            # The generated thunks often contain unused variables.
            "-Wno-unused-variable",
        ],
        linkopts = clinkopts + _DEFAULT_PLATFORM_LINKOPTS,
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
        cgo_objc_lib_name = prefix + "cgo_objc_lib"
        objcopts.update(common_attrs)
        native.objc_library(
            name = cgo_objc_lib_name,
            srcs = [select_objc_files],
            deps = cdeps,
            copts = copts + cppopts + _DEFAULT_PLATFORM_COPTS + [
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
    cgo_o_name = prefix + "_cgo_.o"
    native.cc_binary(
        name = cgo_o_name,
        srcs = [select_main_c],
        deps = cdeps + cgo_o_deps,
        copts = copts + cppopts + [
            # The generated thunks often contain unused variables.
            "-Wno-unused-variable",
        ],
        linkopts = clinkopts,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    # Create a Go file which imports symbols from the C library.
    cgo_import_name = prefix + "cgo_import"
    _cgo_import(
        name = cgo_import_name,
        cgo_o = cgo_o_name,
        sample_go_srcs = [select_go_files],
        visibility = ["//visibility:private"],
        **common_attrs
    )

    cgo_info_name = prefix + "cgo_info"
    _cgo_collect_info(
        name = cgo_info_name,
        srcs = srcs,
        cgo_import = cgo_import_name,
        codegen = cgo_codegen_name,
        libs = cgo_collect_info_libs,
        visibility = ["//visibility:private"],
        **common_attrs
    )
    return cgo_info_name

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
        # These archives can't be built on all platforms, so use "manual" tags.
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
        cc_import_kwargs["alwayslink"] = 1
    native.cc_import(
        name = cc_import_name,
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
