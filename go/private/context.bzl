# Copyright 2017 The Bazel Authors. All rights reserved.
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
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
)
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_COMPILE_ACTION_NAME",
    "CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME",
    "CPP_LINK_EXECUTABLE_ACTION_NAME",
    "CPP_LINK_STATIC_LIBRARY_ACTION_NAME",
    "C_COMPILE_ACTION_NAME",
    "OBJCPP_COMPILE_ACTION_NAME",
    "OBJC_COMPILE_ACTION_NAME",
)
load(
    ":go_toolchain.bzl",
    "GO_TOOLCHAIN",
)
load(
    ":providers.bzl",
    "CgoContextInfo",
    "EXPLICIT_PATH",
    "EXPORT_PATH",
    "GoArchive",
    "GoConfigInfo",
    "GoContextInfo",
    "GoLibrary",
    "GoSource",
    "GoStdLib",
    "INFERRED_PATH",
    "get_source",
)
load(
    ":mode.bzl",
    "get_mode",
    "installsuffix",
)
load(
    ":common.bzl",
    "COVERAGE_OPTIONS_DENYLIST",
    "as_iterable",
    "goos_to_extension",
    "goos_to_shared_extension",
    "is_struct",
)
load(
    "//go/platform:apple.bzl",
    "apple_ensure_options",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//rules:common_settings.bzl",
    "BuildSettingInfo",
)
load(
    "//go/private/rules:transition.bzl",
    "request_nogo_transition",
)

# cgo requires a gcc/clang style compiler.
# We use a denylist instead of an allowlist:
# - Bazel's auto-detected toolchains used to set the compiler name to "compiler"
#   for gcc (fixed in 6.0.0), which defeats the purpose of an allowlist.
# - The compiler name field is free-form and user-defined, so we would have to
#   provide a way to override this list.
# TODO: Convert to a denylist once we can assume Bazel 6.0.0 or later and have a
#       way for users to extend the list.
_UNSUPPORTED_C_COMPILERS = {
    "msvc-cl": None,
    "clang-cl": None,
}

_COMPILER_OPTIONS_DENYLIST = dict({
    # cgo parses the error messages from the compiler.  It can't handle colors.
    # Ignore both variants of the diagnostics color flag.
    "-fcolor-diagnostics": None,
    "-fdiagnostics-color": None,

    # cgo also wants to see all the errors when it is testing the compiler.
    # fmax-errors limits that and causes build failures.
    "-fmax-errors=": None,
    "-Wall": None,

    # Symbols are needed by Go, so keep them
    "-g0": None,

    # Don't compile generated cgo code with coverage. If we do an internal
    # link, we may have undefined references to coverage functions.
    "--coverage": None,
    "-ftest-coverage": None,
    "-fprofile-arcs": None,
    "-fprofile-instr-generate": None,
    "-fcoverage-mapping": None,
}, **COVERAGE_OPTIONS_DENYLIST)

_LINKER_OPTIONS_DENYLIST = {
    "-Wl,--gc-sections": None,
}

_UNSUPPORTED_FEATURES = [
    # These toolchain features require special rule support and will thus break
    # with CGo.
    # Taken from https://github.com/bazelbuild/rules_rust/blob/521e649ff44e9711fe3c45b0ec1e792f7e1d361e/rust/private/utils.bzl#L20.
    "thin_lto",
    "module_maps",
    "use_header_modules",
    "fdo_instrument",
    "fdo_optimize",
]

def _match_option(option, pattern):
    if pattern.endswith("="):
        return option.startswith(pattern)
    else:
        return option == pattern

def _filter_options(options, denylist):
    return [
        option
        for option in options
        if not any([_match_option(option, pattern) for pattern in denylist])
    ]

def _child_name(go, path, ext, name):
    if not name:
        name = go.label.name
        if path or not ext:
            # The '_' avoids collisions with another file matching the label name.
            # For example, hello and hello/testmain.go.
            name += "_"
    if path:
        name += "/" + path
    if ext:
        name += ext
    return name

def _declare_file(go, path = "", ext = "", name = ""):
    return go.actions.declare_file(_child_name(go, path, ext, name))

def _declare_directory(go, path = "", ext = "", name = ""):
    return go.actions.declare_directory(_child_name(go, path, ext, name))

def _new_args(go):
    # TODO(jayconrod): print warning.
    return go.builder_args(go)

def _builder_args(go, command = None):
    args = go.actions.args()
    args.use_param_file("-param=%s")
    args.set_param_file_format("shell")
    if command:
        args.add(command)
    args.add("-sdk", go.sdk.root_file.dirname)
    args.add("-installsuffix", installsuffix(go.mode))
    args.add_joined("-tags", go.tags, join_with = ",")
    return args

def _tool_args(go):
    args = go.actions.args()
    args.use_param_file("-param=%s")
    args.set_param_file_format("shell")
    return args

def _new_library(go, name = None, importpath = None, resolver = None, importable = True, testfilter = None, is_main = False, **kwargs):
    if not importpath:
        importpath = go.importpath
        importmap = go.importmap
    else:
        importmap = importpath
    pathtype = go.pathtype
    if not importable and pathtype == EXPLICIT_PATH:
        pathtype = EXPORT_PATH

    return GoLibrary(
        name = go.label.name if not name else name,
        label = go.label,
        importpath = importpath,
        importmap = importmap,
        importpath_aliases = go.importpath_aliases,
        pathtype = pathtype,
        resolve = resolver,
        testfilter = testfilter,
        is_main = is_main,
        **kwargs
    )

def _merge_embed(source, embed):
    s = get_source(embed)
    source["srcs"] = s.srcs + source["srcs"]
    source["orig_srcs"] = s.orig_srcs + source["orig_srcs"]
    source["orig_src_map"].update(s.orig_src_map)
    source["embedsrcs"] = source["embedsrcs"] + s.embedsrcs
    source["cover"] = source["cover"] + s.cover
    source["deps"] = source["deps"] + s.deps
    source["x_defs"].update(s.x_defs)
    source["gc_goopts"] = source["gc_goopts"] + s.gc_goopts
    source["runfiles"] = source["runfiles"].merge(s.runfiles)
    if s.cgo and source["cgo"]:
        fail("multiple libraries with cgo enabled")
    source["cgo"] = source["cgo"] or s.cgo
    source["cdeps"] = source["cdeps"] or s.cdeps
    source["cppopts"] = source["cppopts"] or s.cppopts
    source["copts"] = source["copts"] or s.copts
    source["cxxopts"] = source["cxxopts"] or s.cxxopts
    source["clinkopts"] = source["clinkopts"] or s.clinkopts
    source["cgo_deps"] = source["cgo_deps"] + s.cgo_deps
    source["cgo_exports"] = source["cgo_exports"] + s.cgo_exports

def _dedup_deps(deps):
    """Returns a list of deps without duplicate import paths.

    Earlier targets take precedence over later targets. This is intended to
    allow an embedding library to override the dependencies of its
    embedded libraries.

    Args:
      deps: an iterable containing either Targets or GoArchives.
    """
    deduped_deps = []
    importpaths = {}
    for dep in deps:
        if hasattr(dep, "data") and hasattr(dep.data, "importpath"):
            importpath = dep.data.importpath
        else:
            importpath = dep[GoLibrary].importpath
        if importpath in importpaths:
            continue
        importpaths[importpath] = None
        deduped_deps.append(dep)
    return deduped_deps

def _library_to_source(go, attr, library, coverage_instrumented):
    #TODO: stop collapsing a depset in this line...
    attr_srcs = [f for t in getattr(attr, "srcs", []) for f in as_iterable(t.files)]
    generated_srcs = getattr(library, "srcs", [])
    srcs = attr_srcs + generated_srcs
    embedsrcs = [f for t in getattr(attr, "embedsrcs", []) for f in as_iterable(t.files)]
    source = {
        "library": library,
        "mode": go.mode,
        "srcs": srcs,
        "orig_srcs": srcs,
        "orig_src_map": {},
        "cover": [],
        "embedsrcs": embedsrcs,
        "x_defs": {},
        "deps": getattr(attr, "deps", []),
        "gc_goopts": _expand_opts(go, "gc_goopts", getattr(attr, "gc_goopts", [])),
        "runfiles": _collect_runfiles(go, getattr(attr, "data", []), getattr(attr, "deps", [])),
        "cgo": getattr(attr, "cgo", False),
        "cdeps": getattr(attr, "cdeps", []),
        "cppopts": _expand_opts(go, "cppopts", getattr(attr, "cppopts", [])),
        "copts": _expand_opts(go, "copts", getattr(attr, "copts", [])),
        "cxxopts": _expand_opts(go, "cxxopts", getattr(attr, "cxxopts", [])),
        "clinkopts": _expand_opts(go, "clinkopts", getattr(attr, "clinkopts", [])),
        "cgo_deps": [],
        "cgo_exports": [],
        "cc_info": None,
    }
    if coverage_instrumented:
        source["cover"] = attr_srcs
    for dep in source["deps"]:
        _check_binary_dep(go, dep, "deps")
    for e in getattr(attr, "embed", []):
        _check_binary_dep(go, e, "embed")
        _merge_embed(source, e)
    source["deps"] = _dedup_deps(source["deps"])
    x_defs = source["x_defs"]
    for k, v in getattr(attr, "x_defs", {}).items():
        v = _expand_location(go, attr, v)
        if "." not in k:
            k = "{}.{}".format(library.importmap, k)
        x_defs[k] = v
    source["x_defs"] = x_defs
    if not source["cgo"]:
        for k in ("cdeps", "cppopts", "copts", "cxxopts", "clinkopts"):
            if getattr(attr, k, None):
                fail(k + " set without cgo = True")
        for f in source["srcs"]:
            # This check won't report directory sources that contain C/C++
            # sources. compilepkg will catch these instead.
            if f.extension in ("c", "cc", "cxx", "cpp", "hh", "hpp", "hxx"):
                fail("source {} has C/C++ extension, but cgo was not enabled (set 'cgo = True')".format(f.path))
    if library.resolve:
        library.resolve(go, attr, source, _merge_embed)
    source["cc_info"] = _collect_cc_infos(source["deps"], source["cdeps"])
    return GoSource(**source)

def _collect_runfiles(go, data, deps):
    """Builds a set of runfiles from the deps and data attributes.

    srcs and their runfiles are not included."""
    files = depset(transitive = [t[DefaultInfo].files for t in data])
    runfiles = go._ctx.runfiles(transitive_files = files)
    for t in data:
        runfiles = runfiles.merge(t[DefaultInfo].data_runfiles)
    for t in deps:
        runfiles = runfiles.merge(get_source(t).runfiles)
    return runfiles

def _collect_cc_infos(deps, cdeps):
    cc_infos = []
    for dep in cdeps:
        if CcInfo in dep:
            cc_infos.append(dep[CcInfo])
    for dep in deps:
        # dep may be a struct, which doesn't support indexing by providers.
        if is_struct(dep):
            continue
        if GoSource in dep:
            cc_infos.append(dep[GoSource].cc_info)
    return cc_common.merge_cc_infos(cc_infos = cc_infos)

def _check_binary_dep(go, dep, edge):
    """Checks that this rule doesn't depend on a go_binary or go_test.

    go_binary and go_test may return provides with useful information for other
    rules (like go_path), but go_binary and go_test may not depend on other
    go_binary and go_binary targets. Their dependencies may be built in
    different modes, resulting in conflicts and opaque errors.
    """
    if (type(dep) == "Target" and
        DefaultInfo in dep and
        getattr(dep[DefaultInfo], "files_to_run", None) and
        dep[DefaultInfo].files_to_run.executable):
        fail("rule {rule} depends on executable {dep} via {edge}. This is not safe for cross-compilation. Depend on go_library instead.".format(
            rule = str(go.label),
            dep = str(dep.label),
            edge = edge,
        ))

def _check_importpaths(ctx):
    paths = []
    p = getattr(ctx.attr, "importpath", "")
    if p:
        paths.append(p)
    p = getattr(ctx.attr, "importmap", "")
    if p:
        paths.append(p)
    paths.extend(getattr(ctx.attr, "importpath_aliases", ()))

    for p in paths:
        if ":" in p:
            fail("import path '%s' contains invalid character :" % p)

def _infer_importpath(ctx):
    DEFAULT_LIB = "go_default_library"
    VENDOR_PREFIX = "/vendor/"

    # Check if paths were explicitly set, either in this rule or in an
    # embedded rule.
    attr_importpath = getattr(ctx.attr, "importpath", "")
    attr_importmap = getattr(ctx.attr, "importmap", "")
    embed_importpath = ""
    embed_importmap = ""
    for embed in getattr(ctx.attr, "embed", []):
        if GoLibrary not in embed:
            continue
        lib = embed[GoLibrary]
        if lib.pathtype == EXPLICIT_PATH:
            embed_importpath = lib.importpath
            embed_importmap = lib.importmap
            break

    importpath = attr_importpath or embed_importpath
    importmap = attr_importmap or embed_importmap or importpath
    if importpath:
        return importpath, importmap, EXPLICIT_PATH

    # Guess an import path based on the directory structure
    # This should only really be relied on for binaries
    importpath = ctx.label.package
    if ctx.label.name != DEFAULT_LIB and not importpath.endswith(ctx.label.name):
        importpath += "/" + ctx.label.name
    if importpath.rfind(VENDOR_PREFIX) != -1:
        importpath = importpath[len(VENDOR_PREFIX) + importpath.rfind(VENDOR_PREFIX):]
    if importpath.startswith("/"):
        importpath = importpath[1:]
    return importpath, importpath, INFERRED_PATH

def go_context(ctx, attr = None):
    """Returns an API used to build Go code.

    See /go/toolchains.rst#go-context
    """
    if not attr:
        attr = ctx.attr
    toolchain = ctx.toolchains[GO_TOOLCHAIN]
    cgo_context_info = None
    go_config_info = None
    stdlib = None
    coverdata = None
    nogo = None
    if hasattr(attr, "_go_context_data"):
        go_context_data = _flatten_possibly_transitioned_attr(attr._go_context_data)
        if CgoContextInfo in go_context_data:
            cgo_context_info = go_context_data[CgoContextInfo]
        go_config_info = go_context_data[GoConfigInfo]
        stdlib = go_context_data[GoStdLib]
        coverdata = go_context_data[GoContextInfo].coverdata
        nogo = go_context_data[GoContextInfo].nogo
    if getattr(attr, "_cgo_context_data", None) and CgoContextInfo in attr._cgo_context_data:
        cgo_context_info = attr._cgo_context_data[CgoContextInfo]
    if getattr(attr, "cgo_context_data", None) and CgoContextInfo in attr.cgo_context_data:
        cgo_context_info = attr.cgo_context_data[CgoContextInfo]
    if hasattr(attr, "_go_config"):
        go_config_info = attr._go_config[GoConfigInfo]
    if hasattr(attr, "_stdlib"):
        stdlib = _flatten_possibly_transitioned_attr(attr._stdlib)[GoStdLib]

    mode = get_mode(ctx, toolchain, cgo_context_info, go_config_info)
    tags = mode.tags
    binary = toolchain.sdk.go

    if stdlib:
        goroot = stdlib.root_file.dirname
    else:
        goroot = toolchain.sdk.root_file.dirname

    env = {
        "GOARCH": mode.goarch,
        "GOOS": mode.goos,
        "GOROOT": goroot,
        "GOROOT_FINAL": "GOROOT",
        "CGO_ENABLED": "0" if mode.pure else "1",

        # If we use --action_env=GOPATH, or in other cases where environment
        # variables are passed through to this builder, the SDK build will try
        # to write to that GOPATH (e.g. for x/net/nettest). This will fail if
        # the GOPATH is on a read-only mount, and is generally a bad idea.
        # Explicitly clear this environment variable to ensure that doesn't
        # happen. See #2291 for more information.
        "GOPATH": "",
    }

    # The level of support is determined by the platform constraints in
    # //go/constraints/amd64.
    # See https://github.com/golang/go/wiki/MinimumRequirements#amd64
    if mode.amd64:
        env["GOAMD64"] = mode.amd64
    if not cgo_context_info:
        crosstool = []
        cgo_tools = None
    else:
        env.update(cgo_context_info.env)
        crosstool = cgo_context_info.crosstool

        # Add C toolchain directories to PATH.
        # On ARM, go tool link uses some features of gcc to complete its work,
        # so PATH is needed on ARM.
        path_set = {}
        if "PATH" in env:
            for p in env["PATH"].split(ctx.configuration.host_path_separator):
                path_set[p] = None
        cgo_tools = cgo_context_info.cgo_tools
        tool_paths = [
            cgo_tools.c_compiler_path,
            cgo_tools.ld_executable_path,
            cgo_tools.ld_static_lib_path,
            cgo_tools.ld_dynamic_lib_path,
        ]
        for tool_path in tool_paths:
            tool_dir, _, _ = tool_path.rpartition("/")
            path_set[tool_dir] = None
        paths = sorted(path_set.keys())
        if ctx.configuration.host_path_separator == ":":
            # HACK: ":" is a proxy for a UNIX-like host.
            # The tools returned above may be bash scripts that reference commands
            # in directories we might not otherwise include. For example,
            # on macOS, wrapped_ar calls dirname.
            if "/bin" not in path_set:
                paths.append("/bin")
            if "/usr/bin" not in path_set:
                paths.append("/usr/bin")
        env["PATH"] = ctx.configuration.host_path_separator.join(paths)

    # TODO(jayconrod): remove this. It's way too broad. Everything should
    # depend on more specific lists.
    sdk_files = ([toolchain.sdk.go] +
                 toolchain.sdk.srcs +
                 toolchain.sdk.headers +
                 toolchain.sdk.libs +
                 toolchain.sdk.tools)

    _check_importpaths(ctx)
    importpath, importmap, pathtype = _infer_importpath(ctx)
    importpath_aliases = tuple(getattr(attr, "importpath_aliases", ()))

    return struct(
        # Fields
        toolchain = toolchain,
        sdk = toolchain.sdk,
        mode = mode,
        root = goroot,
        go = binary,
        stdlib = stdlib,
        sdk_root = toolchain.sdk.root_file,
        sdk_files = sdk_files,
        sdk_tools = toolchain.sdk.tools,
        actions = ctx.actions,
        exe_extension = goos_to_extension(mode.goos),
        shared_extension = goos_to_shared_extension(mode.goos),
        crosstool = crosstool,
        package_list = toolchain.sdk.package_list,
        importpath = importpath,
        importmap = importmap,
        importpath_aliases = importpath_aliases,
        pathtype = pathtype,
        cgo_tools = cgo_tools,
        nogo = nogo,
        coverdata = coverdata,
        coverage_enabled = ctx.configuration.coverage_enabled,
        coverage_instrumented = ctx.coverage_instrumented(),
        env = env,
        tags = tags,
        stamp = mode.stamp,
        label = ctx.label,
        cover_format = mode.cover_format,
        # Action generators
        archive = toolchain.actions.archive,
        binary = toolchain.actions.binary,
        link = toolchain.actions.link,

        # Helpers
        args = _new_args,  # deprecated
        builder_args = _builder_args,
        tool_args = _tool_args,
        new_library = _new_library,
        library_to_source = _library_to_source,
        declare_file = _declare_file,
        declare_directory = _declare_directory,

        # Private
        # TODO: All uses of this should be removed
        _ctx = ctx,
    )

def _go_context_data_impl(ctx):
    if "race" in ctx.features:
        print("WARNING: --features=race is no longer supported. Use --@io_bazel_rules_go//go/config:race instead.")
    if "msan" in ctx.features:
        print("WARNING: --features=msan is no longer supported. Use --@io_bazel_rules_go//go/config:msan instead.")
    nogo = ctx.files.nogo[0] if ctx.files.nogo else None
    providers = [
        GoContextInfo(
            coverdata = ctx.attr.coverdata[GoArchive],
            nogo = nogo,
        ),
        ctx.attr.stdlib[GoStdLib],
        ctx.attr.go_config[GoConfigInfo],
    ]
    if ctx.attr.cgo_context_data and CgoContextInfo in ctx.attr.cgo_context_data:
        providers.append(ctx.attr.cgo_context_data[CgoContextInfo])
    return providers

go_context_data = rule(
    _go_context_data_impl,
    attrs = {
        "cgo_context_data": attr.label(),
        "coverdata": attr.label(
            mandatory = True,
            providers = [GoArchive],
        ),
        "go_config": attr.label(
            mandatory = True,
            providers = [GoConfigInfo],
        ),
        "nogo": attr.label(
            mandatory = True,
            cfg = "exec",
        ),
        "stdlib": attr.label(
            mandatory = True,
            providers = [GoStdLib],
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = """go_context_data gathers information about the build configuration.
    It is a common dependency of all Go targets.""",
    toolchains = [GO_TOOLCHAIN],
    cfg = request_nogo_transition,
)

def _cgo_context_data_impl(ctx):
    # TODO(jayconrod): find a way to get a list of files that comprise the
    # toolchain (to be inputs into actions that need it).
    # ctx.files._cc_toolchain won't work when cc toolchain resolution
    # is switched on.
    cc_toolchain = find_cpp_toolchain(ctx)
    if cc_toolchain.compiler in _UNSUPPORTED_C_COMPILERS:
        return []

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features + _UNSUPPORTED_FEATURES,
    )

    # TODO(jayconrod): keep the environment separate for different actions.
    env = {}

    c_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    c_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )
    c_compile_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = C_COMPILE_ACTION_NAME,
            variables = c_compile_variables,
        ) + ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts,
        _COMPILER_OPTIONS_DENYLIST,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    ))

    cxx_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    cxx_compile_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = CPP_COMPILE_ACTION_NAME,
            variables = cxx_compile_variables,
        ) + ctx.fragments.cpp.copts + ctx.fragments.cpp.cxxopts,
        _COMPILER_OPTIONS_DENYLIST,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = cxx_compile_variables,
    ))

    objc_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    objc_compile_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = OBJC_COMPILE_ACTION_NAME,
            variables = objc_compile_variables,
        ),
        _COMPILER_OPTIONS_DENYLIST,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = OBJC_COMPILE_ACTION_NAME,
        variables = objc_compile_variables,
    ))

    objcxx_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    objcxx_compile_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = OBJCPP_COMPILE_ACTION_NAME,
            variables = objcxx_compile_variables,
        ),
        _COMPILER_OPTIONS_DENYLIST,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = OBJCPP_COMPILE_ACTION_NAME,
        variables = objcxx_compile_variables,
    ))

    ld_executable_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = False,
    )
    ld_executable_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
    )
    ld_executable_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
            variables = ld_executable_variables,
        ) + ctx.fragments.cpp.linkopts,
        _LINKER_OPTIONS_DENYLIST,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = ld_executable_variables,
    ))

    # We don't collect options for static libraries. Go always links with
    # "ar" in "c-archive" mode. We can set the ar executable path with
    # -extar, but the options are hard-coded to something like -q -c -s.
    ld_static_lib_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = False,
    )
    ld_static_lib_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
    )
    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        variables = ld_static_lib_variables,
    ))

    ld_dynamic_lib_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = True,
    )
    ld_dynamic_lib_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME,
    )
    ld_dynamic_lib_options = _filter_options(
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME,
            variables = ld_dynamic_lib_variables,
        ) + ctx.fragments.cpp.linkopts,
        _LINKER_OPTIONS_DENYLIST,
    )

    env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_DYNAMIC_LIBRARY_ACTION_NAME,
        variables = ld_dynamic_lib_variables,
    ))

    tags = []
    if "gotags" in ctx.var:
        tags = ctx.var["gotags"].split(",")
    apple_ensure_options(
        ctx,
        env,
        tags,
        (c_compile_options, cxx_compile_options, objc_compile_options, objcxx_compile_options),
        (ld_executable_options, ld_dynamic_lib_options),
        cc_toolchain.target_gnu_system_name,
    )

    return [CgoContextInfo(
        crosstool = cc_toolchain.all_files.to_list(),
        tags = tags,
        env = env,
        cgo_tools = struct(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            c_compiler_path = c_compiler_path,
            c_compile_options = c_compile_options,
            cxx_compile_options = cxx_compile_options,
            objc_compile_options = objc_compile_options,
            objcxx_compile_options = objcxx_compile_options,
            ld_executable_path = ld_executable_path,
            ld_executable_options = ld_executable_options,
            ld_static_lib_path = ld_static_lib_path,
            ld_dynamic_lib_path = ld_dynamic_lib_path,
            ld_dynamic_lib_options = ld_dynamic_lib_options,
        ),
    )]

cgo_context_data = rule(
    implementation = _cgo_context_data_impl,
    attrs = {
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
        "_xcode_config": attr.label(
            default = "@bazel_tools//tools/osx:current_xcode_config",
        ),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    fragments = ["apple", "cpp"],
    doc = """Collects information about the C/C++ toolchain. The C/C++ toolchain
    is needed to build cgo code, but is generally optional. Rules can't have
    optional toolchains, so instead, we have an optional dependency on this
    rule.""",
)

def _cgo_context_data_proxy_impl(ctx):
    if ctx.attr.actual and CgoContextInfo in ctx.attr.actual:
        return [ctx.attr.actual[CgoContextInfo]]
    return []

cgo_context_data_proxy = rule(
    implementation = _cgo_context_data_proxy_impl,
    attrs = {
        "actual": attr.label(),
    },
    doc = """Conditionally depends on cgo_context_data and forwards it provider.

    Useful in situations where select cannot be used, like attribute defaults.
    """,
)

def _go_config_impl(ctx):
    return [GoConfigInfo(
        static = ctx.attr.static[BuildSettingInfo].value,
        race = ctx.attr.race[BuildSettingInfo].value,
        msan = ctx.attr.msan[BuildSettingInfo].value,
        pure = ctx.attr.pure[BuildSettingInfo].value,
        strip = ctx.attr.strip[BuildSettingInfo].value,
        debug = ctx.attr.debug[BuildSettingInfo].value,
        linkmode = ctx.attr.linkmode[BuildSettingInfo].value,
        gc_linkopts = ctx.attr.gc_linkopts[BuildSettingInfo].value,
        tags = ctx.attr.gotags[BuildSettingInfo].value,
        stamp = ctx.attr.stamp,
        cover_format = ctx.attr.cover_format[BuildSettingInfo].value,
        gc_goopts = ctx.attr.gc_goopts[BuildSettingInfo].value,
        amd64 = ctx.attr.amd64,
    )]

go_config = rule(
    implementation = _go_config_impl,
    attrs = {
        "static": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "race": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "msan": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "pure": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "strip": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "debug": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "linkmode": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "gc_linkopts": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "gotags": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "stamp": attr.bool(mandatory = True),
        "cover_format": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "gc_goopts": attr.label(
            mandatory = True,
            providers = [BuildSettingInfo],
        ),
        "amd64": attr.string(),
    },
    provides = [GoConfigInfo],
    doc = """Collects information about build settings in the current
    configuration. Rules may depend on this instead of depending on all
    the build settings directly.""",
)

def _expand_opts(go, attribute_name, opts):
    return [go._ctx.expand_make_variables(attribute_name, opt, {}) for opt in opts]

def _expand_location(go, attr, s):
    return go._ctx.expand_location(s, getattr(attr, "data", []))

_LIST_TYPE = type([])

# Used to get attribute values which may have been transitioned.
# Transitioned attributes end up as lists.
# We never use split-transitions, so we always expect exactly one element in those lists.
# But if the attribute wasn't transitioned, it won't be a list.
def _flatten_possibly_transitioned_attr(maybe_list):
    if type(maybe_list) == _LIST_TYPE:
        if len(maybe_list) == 1:
            return maybe_list[0]
        else:
            fail("Expected exactly one element in list but got {}".format(maybe_list))
    return maybe_list
