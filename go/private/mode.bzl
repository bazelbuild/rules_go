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

def new_mode(goos, goarch, static = False, race = False, msan = False, pure = False, link = LINKMODE_NORMAL, debug = False, strip = False):
    return struct(
        static = static,
        race = race,
        msan = msan,
        pure = pure,
        link = link,
        debug = debug,
        strip = strip,
        goos = goos,
        goarch = goarch,
    )

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

def get_mode(ctx, host_only, go_toolchain, go_context_data):
    aspect_cross_compile = False
    goos = go_toolchain.default_goos
    attr_goos = getattr(ctx.attr, "goos", "auto")
    if goos != attr_goos and attr_goos != "auto":
        goos = attr_goos
        aspect_cross_compile = True
    goarch = go_toolchain.default_goarch
    attr_goarch = getattr(ctx.attr, "goarch", "auto")
    if goarch != attr_goarch and attr_goarch != "auto":
        goarch = attr_goarch
        aspect_cross_compile = True

    # We have to build in pure mode if we don't have a C toolchain.
    # If we're cross-compiling using the aspect, we might have a C toolchain
    # for the wrong platform, so also force pure mode then.
    force_pure = "on" if not go_context_data.cgo_tools or aspect_cross_compile else "auto"

    force_race = "off" if host_only else "auto"

    linkmode = getattr(ctx.attr, "linkmode", LINKMODE_NORMAL)
    if linkmode in [LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE, LINKMODE_PIE]:
        if not go_context_data.cgo_tools:
            fail("linkmode is {}, but no C/C++ toolchain is configured".format(linkmode))
        force_pure = "off"

    static = _ternary(
        getattr(ctx.attr, "static", None),
        "static" in ctx.features,
    )
    race = _ternary(
        getattr(ctx.attr, "race", None),
        force_race,
        "race" in ctx.features,
    )
    msan = _ternary(
        getattr(ctx.attr, "msan", None),
        "msan" in ctx.features,
    )
    pure = _ternary(
        getattr(ctx.attr, "pure", None),
        force_pure,
        "pure" in ctx.features,
    )
    if race and pure:
        # You are not allowed to compile in race mode with pure enabled
        race = False
    debug = ctx.var["COMPILATION_MODE"] == "dbg"
    strip_mode = "sometimes"
    if go_context_data:
        strip_mode = go_context_data.strip
    strip = False
    if strip_mode == "always":
        strip = True
    elif strip_mode == "sometimes":
        strip = not debug

    return struct(
        static = static,
        race = race,
        msan = msan,
        pure = pure,
        link = linkmode,
        debug = debug,
        strip = strip,
        goos = goos,
        goarch = goarch,
    )

def installsuffix(mode):
    s = mode.goos + "_" + mode.goarch
    if mode.race:
        s += "_race"
    elif mode.msan:
        s += "_msan"
    return s

def mode_tags_equivalent(l, r):
    """Returns whether two modes are equivalent for Go build tags. For example,
    goos and goarch must match, but static doesn't matter."""
    return (l.goos == r.goos and
            l.goarch == r.goarch and
            l.race == r.race and
            l.msan == r.msan)

# Ported from https://github.com/golang/go/blob/master/src/cmd/go/internal/work/init.go#L76
_LINK_C_ARCHIVE_PLATFORMS = {
    "darwin/arm": None,
    "darwin/arm64": None,
}

_LINK_C_ARCHIVE_GOOS = {
    "dragonfly": None,
    "freebsd": None,
    "linux": None,
    "netbsd": None,
    "openbsd": None,
    "solaris": None,
}

_LINK_C_SHARED_PLATFORMS = {
    "linux/amd64": None,
    "linux/arm": None,
    "linux/arm64": None,
    "linux/386": None,
    "linux/ppc64le": None,
    "linux/s390x": None,
    "android/amd64": None,
    "android/arm": None,
    "android/arm64": None,
    "android/386": None,
}

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
        if platform in _LINK_C_SHARED_PLATFORMS:
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
        if go.mode.goos == "darwin":
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
