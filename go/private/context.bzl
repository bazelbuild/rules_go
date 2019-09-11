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
    "@io_bazel_rules_go_compat//:compat.bzl",
    "cc_configure_features",
    "cc_toolchain_all_files",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "CgoContextData",
    "EXPLICIT_PATH",
    "EXPORT_PATH",
    "GoLibrary",
    "GoSource",
    "GoStdLib",
    "INFERRED_PATH",
    "get_archive",
    "get_source",
)
load(
    "@io_bazel_rules_go//go/platform:list.bzl",
    "GOOS_GOARCH",
)
load(
    "@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
    "installsuffix",
    "mode_string",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "as_iterable",
    "goos_to_extension",
    "goos_to_shared_extension",
)
load(
    "@io_bazel_rules_go//go/platform:apple.bzl",
    "apple_ensure_options",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

GoContext = provider()
_GoContextData = provider()

_COMPILER_OPTIONS_BLACKLIST = {
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
}

_LINKER_OPTIONS_BLACKLIST = {
    "-Wl,--gc-sections": None,
}

def _match_option(option, pattern):
    if pattern.endswith("="):
        return option.startswith(pattern)
    else:
        return option == pattern

def _filter_options(options, blacklist):
    return [
        option
        for option in options
        if not any([_match_option(option, pattern) for pattern in blacklist])
    ]

def _child_name(go, path, ext, name):
    childname = mode_string(go.mode) + "/"
    childname += name if name else go._ctx.label.name
    if path:
        childname += "%/" + path
    if ext:
        childname += ext
    return childname

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
    args.set_param_file_format("multiline")
    if command:
        args.add(command)
    args.add("-sdk", go.sdk.root_file.dirname)
    args.add("-installsuffix", installsuffix(go.mode))
    args.add_joined("-tags", go.tags, join_with = ",")
    return args

def _tool_args(go):
    args = go.actions.args()
    args.use_param_file("-param=%s")
    args.set_param_file_format("multiline")
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
        name = go._ctx.label.name if not name else name,
        label = go._ctx.label,
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
    """Returns a list of targets without duplicate import paths.

    Earlier targets take precedence over later targets. This is intended to
    allow an embedding library to override the dependencies of its
    embedded libraries.
    """
    deduped_deps = []
    importpaths = {}
    for dep in deps:
        # TODO(#1784): we allow deps to be a list of GoArchive since go_test and
        # nogo work this way. We should force deps to be a list of Targets.
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
    source = {
        "library": library,
        "mode": go.mode,
        "srcs": srcs,
        "orig_srcs": srcs,
        "orig_src_map": {},
        "cover": [],
        "x_defs": {},
        "deps": getattr(attr, "deps", []),
        "gc_goopts": getattr(attr, "gc_goopts", []),
        "runfiles": _collect_runfiles(go, getattr(attr, "data", []), getattr(attr, "deps", [])),
        "cgo": getattr(attr, "cgo", False),
        "cdeps": getattr(attr, "cdeps", []),
        "cppopts": getattr(attr, "cppopts", []),
        "copts": getattr(attr, "copts", []),
        "cxxopts": getattr(attr, "cxxopts", []),
        "clinkopts": getattr(attr, "clinkopts", []),
        "cgo_deps": [],
        "cgo_exports": [],
    }
    if coverage_instrumented and not getattr(attr, "testonly", False):
        source["cover"] = attr_srcs
    for dep in source["deps"]:
        _check_binary_dep(go, dep, "deps")
    for e in getattr(attr, "embed", []):
        _check_binary_dep(go, e, "embed")
        _merge_embed(source, e)
    source["deps"] = _dedup_deps(source["deps"])
    x_defs = source["x_defs"]
    for k, v in getattr(attr, "x_defs", {}).items():
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
    return GoSource(**source)

def _collect_runfiles(go, data, deps):
    """Builds a set of runfiles from the deps and data attributes. srcs and
    their runfiles are not included."""
    files = depset(transitive = [t[DefaultInfo].files for t in data])
    runfiles = go._ctx.runfiles(transitive_files = files)
    for t in data:
        runfiles = runfiles.merge(t[DefaultInfo].data_runfiles)
    for t in deps:
        runfiles = runfiles.merge(get_source(t).runfiles)
    return runfiles

def _check_binary_dep(go, dep, edge):
    """Checks that this rule doesn't depend on a go_binary or go_test.

    go_binary and go_test apply an aspect to their deps and embeds. If a
    go_binary / go_test depends on another go_binary / go_test in different
    modes, the aspect is applied twice, and Bazel emits an opaque error
    message.
    """
    if (type(dep) == "Target" and
        DefaultInfo in dep and
        getattr(dep[DefaultInfo], "files_to_run", None) and
        dep[DefaultInfo].files_to_run.executable):
        # TODO(#1735): make this an error after 0.16 is released.
        print("WARNING: rule {rule} depends on executable {dep} via {edge}. This is not safe for cross-compilation. Depend on go_library instead. This will be an error in the future.".format(
            rule = str(go._ctx.label),
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
    toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]

    if not attr:
        attr = ctx.attr

    nogo = None
    if hasattr(attr, "_nogo"):
        nogo_files = attr._nogo.files.to_list()
        if nogo_files:
            nogo = nogo_files[0]

    coverdata = getattr(attr, "_coverdata", None)
    if coverdata:
        coverdata = get_archive(coverdata)

    host_only = getattr(attr, "_hostonly", False)

    context_data = attr._go_context_data[_GoContextData]
    mode = get_mode(ctx, host_only, toolchain, context_data)
    tags = list(context_data.tags)
    if mode.race:
        tags.append("race")
    if mode.msan:
        tags.append("msan")
    binary = toolchain.sdk.go

    stdlib = getattr(attr, "_stdlib", None)
    if stdlib:
        stdlib = get_source(stdlib).stdlib
        goroot = stdlib.root_file.dirname
    else:
        goroot = toolchain.sdk.root_file.dirname

    env = dict(context_data.env)
    env.update({
        "GOARCH": mode.goarch,
        "GOOS": mode.goos,
        "GOROOT": goroot,
        "GOROOT_FINAL": "GOROOT",
        "CGO_ENABLED": "0" if mode.pure else "1",
    })

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

    return GoContext(
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
        crosstool = context_data.crosstool,
        package_list = toolchain.sdk.package_list,
        importpath = importpath,
        importmap = importmap,
        importpath_aliases = importpath_aliases,
        pathtype = pathtype,
        cgo_tools = context_data.cgo_tools,
        nogo = nogo,
        coverdata = coverdata,
        coverage_enabled = ctx.configuration.coverage_enabled,
        coverage_instrumented = ctx.coverage_instrumented(),
        env = env,
        tags = tags,
        stamp = context_data.stamp,
        # Action generators
        archive = toolchain.actions.archive,
        asm = toolchain.actions.asm,
        binary = toolchain.actions.binary,
        compile = toolchain.actions.compile,
        cover = toolchain.actions.cover,
        link = toolchain.actions.link,
        pack = toolchain.actions.pack,

        # Helpers
        args = _new_args,  # deprecated
        builder_args = _builder_args,
        tool_args = _tool_args,
        new_library = _new_library,
        library_to_source = _library_to_source,
        declare_file = _declare_file,
        declare_directory = _declare_directory,

        # Private
        _ctx = ctx,  # TODO: All uses of this should be removed
    )

def _go_context_data_impl(ctx):
    if ctx.attr.cgo_context_data:
        cgo_context_data = ctx.attr.cgo_context_data[CgoContextData]
        crosstool = cgo_context_data.crosstool
        env = dict(cgo_context_data.env)
        tags = cgo_context_data.tags
        cgo_tools = cgo_context_data.cgo_tools
        tool_paths = [
            cgo_tools.c_compiler_path,
            cgo_tools.ld_executable_path,
            cgo_tools.ld_static_lib_path,
            cgo_tools.ld_dynamic_lib_path,
        ]
    else:
        crosstool = []
        env = {}
        tags = ctx.var["gotags"].split(",") if "gotags" in ctx.var else []
        cgo_tools = None
        tool_paths = []

    # Add C toolchain directories to PATH.
    # On ARM, go tool link uses some features of gcc to complete its work,
    # so PATH is needed on ARM.
    path_set = {}
    if "PATH" in env:
        for p in env["PATH"].split(ctx.configuration.host_path_separator):
            path_set[p] = None
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

    return [_GoContextData(
        stamp = ctx.attr.stamp,
        strip = ctx.attr.strip,
        crosstool = crosstool,
        tags = tags,
        env = env,
        cgo_tools = cgo_tools,
    )]

go_context_data = rule(
    _go_context_data_impl,
    attrs = {
        "stamp": attr.bool(mandatory = True),
        "strip": attr.string(mandatory = True),
        "cgo_context_data": attr.label(),
    },
    doc = """go_context_data gathers information about the build configuration.
It is a common dependency of all Go targets.""",
)

def _cgo_context_data_impl(ctx):
    # TODO(jayconrod): find a way to get a list of files that comprise the
    # toolchain (to be inputs into actions that need it).
    # ctx.files._cc_toolchain won't work when cc toolchain resolution
    # is switched on.
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
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
        ),
        _COMPILER_OPTIONS_BLACKLIST,
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
        ),
        _COMPILER_OPTIONS_BLACKLIST,
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
        _COMPILER_OPTIONS_BLACKLIST,
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
        _COMPILER_OPTIONS_BLACKLIST,
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
        ),
        _LINKER_OPTIONS_BLACKLIST,
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
        ),
        _LINKER_OPTIONS_BLACKLIST,
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

    return [CgoContextData(
        crosstool = cc_toolchain_all_files(ctx),
        tags = tags,
        env = env,
        cgo_tools = struct(
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
    provides = [CgoContextData],
)
