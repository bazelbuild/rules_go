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

"""
  [Bazel build settings]: https://docs.bazel.build/versions/master/skylark/config.html#using-build-settings
  [Bazel configuration transitions]: https://docs.bazel.build/versions/master/skylark/lib/transition.html
  [Bazel platform]: https://docs.bazel.build/versions/master/platforms.html
  [go_library]: core.rst#go_library
  [go_binary]: core.rst#go_binary
  [go_test]: core.rst#go_test
  [toolchain]: toolchains.rst#the-toolchain-object
  [config_setting]: https://docs.bazel.build/versions/master/be/general.html#config_setting
  [platform]: https://docs.bazel.build/versions/master/be/platform.html#platform
  [select]: https://docs.bazel.build/versions/master/be/functions.html#select

# Build modes

## Contents
- [Overview](#overview)
- [Build settings](#build-settings)
- [Platforms](#platforms)
- [Examples](#examples)
  - [Building pure go binaries](#building-pure-go-binaries)
  - [Building static binaries](#building-static-binaries)
  - [Using the race detector](#using-the-race-detector)

## Additional resources
- [Bazel build settings]
- [Bazel configuration transitions]
- [Bazel platform]
- [go_library]
- [go_binary]
- [go_test]
- [toolchain]
- [config_setting]
- [platform]
- [select]

------------------------------------------------------------------------

Overview
--------

The Go toolchain can be configured to build targets in different modes using
[Bazel build settings] specified on the command line or by using attributes
specified on individual [go_binary] or [go_test] targets. For example, tests
may be run in race mode with the command line flag
`--@io_bazel_rules_go//go/config:race` or by setting `race = "on"` on the
individual test targets.

Similarly, the Go toolchain can be made to cross-compile binaries for a specific
platform by setting the `--platforms` command line flag or by setting the
`goos` and `goarch` attributes of the binary target. For example, a binary
could be built for `linux` / `arm64` using the command line flag
`--platforms=@io_bazel_rules_go//go/toolchain:linux_arm64` or by setting
`goos = "linux"` and `goarch = "arm64"`.

Build settings
--------------

The build settings below are defined in the package
`@io_bazel_rules_go//go/config`. They can all be set on the command line
or using `Bazel configuration transitions`.

TODO: generate table

Platforms
---------

You can define a [Bazel platform] using the native [platform] rule. A platform
is essentially a list of facts (constraint values) about a target platform.
rules_go defines a `platform` for each configuration the Go toolchain supports
in `@io_bazel_rules_go//go/toolchain`. There are also [config_setting] targets
in `@io_bazel_rules_go//go/platform` that can be used to pick platform-specific
sources or dependencies using [select].

You can specify a target platform using the `--platforms` command line flag.
Bazel will automatically select a registered toolchain compatible with the
target platform (rules_go registers toolchains for all supported platforms).
For example, you could build for Linux / arm64 with the flag
`--platforms=@io_bazel_rules_go//go/toolchain:linux_arm64`.

You can set the `goos` and `goarch` attributes on an individual
[go_binary] or [go_test] rule to build a binary for a specific platform.
This sets the `--platforms` flag via [Bazel configuration transitions].


Examples
--------

Building pure go binaries
-------------------------

You can switch the default binaries to non cgo using

``` bash
bazel build --@io_bazel_rules_go//go/config:pure //:my_binary
```

You can build pure go binaries by setting those attributes on a binary.

``` bzl
go_binary(
    name = "foo",
    srcs = ["foo.go"],
    pure = "on",
)
```


Building static binaries
------------------------

| Note that static linking does not work on darwin.

You can switch the default binaries to statically linked binaries using

``` bash
bazel build --@io_bazel_rules_go//go/config:static //:my_binary
```

You can build static go binaries by setting those attributes on a binary.
If you want it to be fully static (no libc), you should also specify pure.

``` bzl
go_binary(
    name = "foo",
    srcs = ["foo.go"],
    static = "on",
)
```

Using the race detector
-----------------------

You can switch the default binaries to race detection mode, and thus also switch
the mode of tests by using

``` bash
bazel test --@io_bazel_rules_go//go/config:race //...
```

Alternatively, you can activate race detection for specific tests.

``` bzl
go_test(
    name = "go_default_test",
    srcs = ["lib_test.go"],
    embed = [":go_default_library"],
    race = "on",
)
```
"""

LINKMODE_NORMAL = "normal"

LINKMODE_SHARED = "shared"

LINKMODE_PIE = "pie"

LINKMODE_PLUGIN = "plugin"

LINKMODE_C_SHARED = "c-shared"

LINKMODE_C_ARCHIVE = "c-archive"

LINKMODES = [LINKMODE_NORMAL, LINKMODE_PLUGIN, LINKMODE_C_SHARED, LINKMODE_C_ARCHIVE, LINKMODE_PIE]

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
    goos = go_toolchain.default_goos
    goarch = go_toolchain.default_goarch

    # TODO(jayconrod): check for more invalid and contradictory settings.
    if pure and race:
        fail("race instrumentation can't be enabled when cgo is disabled. Check that pure is not set to \"off\" and a C/C++ toolchain is configured.")
    if pure and msan:
        fail("msan instrumentation can't be enabled when cgo is disabled. Check that pure is not set to \"off\" and a C/C++ toolchain is configured.")

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
        strip = strip,
        stamp = stamp,
        debug = debug,
        goos = goos,
        goarch = goarch,
        tags = tags,
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
    "darwin/arm64": None,
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
