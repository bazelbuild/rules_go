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

LINKMODES = [LINKMODE_NORMAL, LINKMODE_PLUGIN, LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE]

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
    # We always have to  use the pure stdlib in cross compilation mode
    force_pure = "on" if go_toolchain.cross_compile else "auto"
    force_race = "off" if host_only else "auto"

    linkmode = getattr(ctx.attr, "linkmode", LINKMODE_NORMAL)
    if linkmode in [LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE]:
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
    goos = getattr(ctx.attr, "goos", None)
    if goos == None or goos == "auto":
        goos = go_toolchain.default_goos
    goarch = getattr(ctx.attr, "goarch", None)
    if goarch == None or goarch == "auto":
        goarch = go_toolchain.default_goarch

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
    return args
