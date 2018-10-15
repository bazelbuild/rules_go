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
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "EXPLICIT_PATH",
    "EXPORT_PATH",
    "GoBuilders",
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
    "paths",
    "structs",
)
load(
    "@io_bazel_rules_go//go/platform:apple.bzl",
    "apple_ensure_options",
)

GoContext = provider()
_GoContextData = provider()

_COMPILER_OPTIONS_BLACKLIST = {
    "-fcolor-diagnostics": None,
    "-Wall": None,
    "-g0": None,  # symbols are needed by Go, so keep them
}

_LINKER_OPTIONS_BLACKLIST = {
    "-Wl,--gc-sections": None,
}

def _filter_options(options, blacklist):
    return [option for option in options if option not in blacklist]

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

def _builder_args(go):
    args = go.actions.args()
    args.use_param_file("-param=%s")
    args.set_param_file_format("multiline")
    args.add("-sdk", go.sdk.root_file.dirname)
    args.add("-installsuffix", installsuffix(go.mode))
    args.add_joined("-tags", go.tags, join_with = ",")
    return args

def _tool_args(go):
    args = go.actions.args()
    args.use_param_file("-param=%s")
    args.set_param_file_format("multiline")
    return args

def _new_library(go, name = None, importpath = None, resolver = None, importable = True, testfilter = None, **kwargs):
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
        pathtype = pathtype,
        resolve = resolver,
        testfilter = testfilter,
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
    source["cgo_deps"] = source["cgo_deps"] + s.cgo_deps
    source["cgo_exports"] = source["cgo_exports"] + s.cgo_exports
    if s.cgo_archives:
        if source["cgo_archives"]:
            fail("multiple libraries with cgo_archives embedded")
        source["cgo_archives"] = s.cgo_archives

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
        "runfiles": go._ctx.runfiles(collect_data = True),
        "cgo_archives": [],
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
    x_defs = source["x_defs"]
    for k, v in getattr(attr, "x_defs", {}).items():
        if "." not in k:
            k = "{}.{}".format(library.importmap, k)
        x_defs[k] = v
    source["x_defs"] = x_defs
    if library.resolve:
        library.resolve(go, attr, source, _merge_embed)
    return GoSource(**source)

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

    builders = getattr(attr, "_builders", None)
    if builders:
        builders = builders[GoBuilders]

    nogo = ctx.files._nogo[0] if getattr(ctx.files, "_nogo", None) else None

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

    importpath, importmap, pathtype = _infer_importpath(ctx)
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
        pathtype = pathtype,
        cgo_tools = context_data.cgo_tools,
        builders = builders,
        nogo = nogo,
        coverdata = coverdata,
        coverage_enabled = ctx.configuration.coverage_enabled,
        coverage_instrumented = ctx.coverage_instrumented(),
        env = env,
        tags = tags,
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
    # TODO(jayconrod): find a way to get a list of files that comprise the
    # toolchain (to be inputs into actions that need it).
    # ctx.files._cc_toolchain won't work when cc toolchain resolution
    # is switched on.
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
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
        (c_compile_options, cxx_compile_options),
        (ld_executable_options, ld_dynamic_lib_options),
        cc_toolchain.target_gnu_system_name,
    )

    # Add C toolchain directories to PATH.
    # On ARM, go tool link uses some features of gcc to complete its work,
    # so PATH is needed on ARM.
    path_set = {}
    if "PATH" in env:
        for p in env["PATH"].split(ctx.configuration.host_path_separator):
            path_set[p] = None
    for tool_path in [c_compiler_path, ld_executable_path, ld_static_lib_path, ld_dynamic_lib_path]:
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
        strip = ctx.attr.strip,
        crosstool = ctx.files._cc_toolchain,
        tags = tags,
        env = env,
        cgo_tools = struct(
            c_compiler_path = c_compiler_path,
            c_compile_options = c_compile_options,
            cxx_compile_options = cxx_compile_options,
            ld_executable_path = ld_executable_path,
            ld_executable_options = ld_executable_options,
            ld_static_lib_path = ld_static_lib_path,
            ld_dynamic_lib_path = ld_dynamic_lib_path,
            ld_dynamic_lib_options = ld_dynamic_lib_options,
        ),
    )]

go_context_data = rule(
    _go_context_data_impl,
    attrs = {
        "strip": attr.string(mandatory = True),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
        "_xcode_config": attr.label(
            default = "@bazel_tools//tools/osx:current_xcode_config",
        ),
    },
    fragments = ["apple"],
)
