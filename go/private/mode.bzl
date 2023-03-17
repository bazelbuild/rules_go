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

# Modes are documented in go/modes.rst#compilation-modes

LINKMODE_NORMAL = "normal"

LINKMODE_SHARED = "shared"

LINKMODE_PIE = "pie"

LINKMODE_PLUGIN = "plugin"

LINKMODE_C_SHARED = "c-shared"

LINKMODE_C_ARCHIVE = "c-archive"

LINKMODES = [LINKMODE_NORMAL, LINKMODE_PLUGIN, LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE, LINKMODE_PIE]

# All link modes that produce executables to be run with bazel run.
LINKMODES_EXECUTABLE = [LINKMODE_NORMAL, LINKMODE_PIE]

# All link modes that require external linking and thus a cgo context.
LINKMODES_REQUIRING_EXTERNAL_LINKING = [
    LINKMODE_PLUGIN,
    LINKMODE_C_ARCHIVE,
    LINKMODE_C_SHARED,
]

def mode_string(mode):
    result = [mode.goos, mode.goarch]
    if mode.static:
        result.append("static")
    if mode.race:
        result.append("race")
    if mode.msan:
        result.append("msan")
    if mode.pure:
        result.append("pure")
    if mode.debug:
        result.append("debug")
    if mode.strip:
        result.append("stripped")
    if not result or not mode.link == LINKMODE_NORMAL:
        result.append(mode.link)
    if mode.gc_goopts:
        result.extend(mode.gc_goopts)
    return "_".join(result)

def _ternary(*values):
    for v in values:
        if v == None:
            continue
        if type(v) == "bool":
            return v
        if type(v) != "string":
            fail("Invalid value type {}".format(type(v)))
        v = v.lower()
        if v == "on":
            return True
        if v == "off":
            return False
        if v == "auto":
            continue
        fail("Invalid value {}".format(v))
    fail("_ternary failed to produce a final result from {}".format(values))

def get_mode(ctx, go_toolchain, cgo_context_info, go_config_info):
    static = _ternary(go_config_info.static if go_config_info else "off")
    pure = _ternary(
        "on" if not cgo_context_info else "auto",
        go_config_info.pure if go_config_info else "off",
    )
    race = _ternary(go_config_info.race if go_config_info else "off")
    msan = _ternary(go_config_info.msan if go_config_info else "off")
    strip = go_config_info.strip if go_config_info else False
    stamp = go_config_info.stamp if go_config_info else False
    debug = go_config_info.debug if go_config_info else False
    linkmode = go_config_info.linkmode if go_config_info else LINKMODE_NORMAL
    cover_format = go_config_info and go_config_info.cover_format
    amd64 = go_config_info.amd64 if go_config_info else None
    goos = go_toolchain.default_goos if getattr(ctx.attr, "goos", "auto") == "auto" else ctx.attr.goos
    goarch = go_toolchain.default_goarch if getattr(ctx.attr, "goarch", "auto") == "auto" else ctx.attr.goarch
    gc_goopts = go_config_info.gc_goopts if go_config_info else []

    # TODO(jayconrod): check for more invalid and contradictory settings.
    if pure and race:
        fail("race instrumentation can't be enabled when cgo is disabled. Check that pure is not set to \"off\" and a C/C++ toolchain is configured.")
    if pure and msan:
        fail("msan instrumentation can't be enabled when cgo is disabled. Check that pure is not set to \"off\" and a C/C++ toolchain is configured.")
    if pure and linkmode in LINKMODES_REQUIRING_EXTERNAL_LINKING:
        fail(("linkmode '{}' can't be used when cgo is disabled. Check that pure is not set to \"off\" and that a C/C++ toolchain is configured for " +
              "your current platform. If you defined a custom platform, make sure that it has the @io_bazel_rules_go//go/toolchain:cgo_on constraint value.").format(linkmode))

    gc_linkopts = list(go_config_info.gc_linkopts) if go_config_info else []
    tags = list(go_config_info.tags) if go_config_info else []
    if "gotags" in ctx.var:
        tags.extend(ctx.var["gotags"].split(","))
    if cgo_context_info:
        tags.extend(cgo_context_info.tags)
    if race:
        tags.append("race")
    if msan:
        tags.append("msan")

    return struct(
        static = static,
        race = race,
        msan = msan,
        pure = pure,
        link = linkmode,
        gc_linkopts = gc_linkopts,
        strip = strip,
        stamp = stamp,
        debug = debug,
        goos = goos,
        goarch = goarch,
        tags = tags,
        cover_format = cover_format,
        amd64 = amd64,
        gc_goopts = gc_goopts,
    )

def installsuffix(mode):
    s = mode.goos + "_" + mode.goarch
    if mode.race:
        s += "_race"
    elif mode.msan:
        s += "_msan"
    return s

def mode_tags_equivalent(l, r):
    # Returns whether two modes are equivalent for Go build tags. For example,
    # goos and goarch must match, but static doesn't matter.
    return (l.goos == r.goos and
            l.goarch == r.goarch and
            l.race == r.race and
            l.msan == r.msan)

# Ported from https://github.com/golang/go/blob/master/src/cmd/go/internal/work/init.go#L76
_LINK_C_ARCHIVE_PLATFORMS = {
    "darwin/arm64": None,
    "ios/arm64": None,
}

_LINK_C_ARCHIVE_GOOS = {
    "dragonfly": None,
    "freebsd": None,
    "linux": None,
    "netbsd": None,
    "openbsd": None,
    "solaris": None,
}

_LINK_C_SHARED_GOOS = [
    "android",
    "freebsd",
    "linux",
]

_LINK_PLUGIN_PLATFORMS = {
    "linux/amd64": None,
    "linux/arm": None,
    "linux/arm64": None,
    "linux/386": None,
    "linux/s390x": None,
    "linux/ppc64le": None,
    "android/amd64": None,
    "android/arm": None,
    "android/arm64": None,
    "android/386": None,
    "darwin/amd64": None,
    "darwin/arm64": None,
    "ios/arm": None,
    "ios/arm64": None,
}

_LINK_PIE_PLATFORMS = {
    "linux/amd64": None,
    "linux/arm": None,
    "linux/arm64": None,
    "linux/386": None,
    "linux/s390x": None,
    "linux/ppc64le": None,
    "android/amd64": None,
    "android/arm": None,
    "android/arm64": None,
    "android/386": None,
    "freebsd/amd64": None,
}

def link_mode_args(mode):
    # based on buildModeInit in cmd/go/internal/work/init.go
    platform = mode.goos + "/" + mode.goarch
    args = []
    if mode.link == LINKMODE_C_ARCHIVE:
        if (platform in _LINK_C_ARCHIVE_PLATFORMS or
            mode.goos in _LINK_C_ARCHIVE_GOOS and platform != "linux/ppc64"):
            args.append("-shared")
    elif mode.link == LINKMODE_C_SHARED:
        if mode.goos in _LINK_C_SHARED_GOOS:
            args.append("-shared")
    elif mode.link == LINKMODE_PLUGIN:
        if platform in _LINK_PLUGIN_PLATFORMS:
            args.append("-dynlink")
    elif mode.link == LINKMODE_PIE:
        if platform in _LINK_PIE_PLATFORMS:
            args.append("-shared")
    return args

def extldflags_from_cc_toolchain(go):
    if not go.cgo_tools:
        return []
    elif go.mode.link in (LINKMODE_SHARED, LINKMODE_PLUGIN, LINKMODE_C_SHARED):
        return go.cgo_tools.ld_dynamic_lib_options
    else:
        # NOTE: in c-archive mode, -extldflags are ignored by the linker.
        # However, we still need to set them for cgo, which links a binary
        # in each package. We use the executable options for this.
        return go.cgo_tools.ld_executable_options

def extld_from_cc_toolchain(go):
    if not go.cgo_tools:
        return []
    elif go.mode.link in (LINKMODE_SHARED, LINKMODE_PLUGIN, LINKMODE_C_SHARED, LINKMODE_PIE):
        return ["-extld", go.cgo_tools.ld_dynamic_lib_path]
    elif go.mode.link == LINKMODE_C_ARCHIVE:
        if go.mode.goos in ["darwin", "ios"]:
            # TODO(jayconrod): on macOS, set -extar. At this time, wrapped_ar is
            # a bash script without a shebang line, so we can't execute it. We
            # use /usr/bin/ar (the default) instead.
            return []
        else:
            return ["-extar", go.cgo_tools.ld_static_lib_path]
    else:
        # NOTE: In c-archive mode, we should probably set -extar. However,
        # on macOS, Bazel returns wrapped_ar, which is not executable.
        # /usr/bin/ar (the default) should be visible though, and we have a
        # hack in link.go to strip out non-reproducible stuff.
        return ["-extld", go.cgo_tools.ld_executable_path]
