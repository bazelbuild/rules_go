# Copyright 2020 The Bazel Authors. All rights reserved.
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
    ":mode.bzl",
    "LINKMODES",
    "LINKMODE_NORMAL",
)
load(
    ":platforms.bzl",
    "CGO_GOOS_GOARCH",
    "GOOS_GOARCH",
)
load(
    ":providers.bzl",
    "GoArchive",
    "GoLibrary",
    "GoSource",
)
load(
    "@io_bazel_rules_go_name_hack//:def.bzl",
    "IS_RULES_GO",
)

def filter_transition_label(label):
    """Transforms transition labels for the current workspace.

    This is a workaround for bazelbuild/bazel#10499. If a transition refers to
    a build setting in the same workspace, for example
    @io_bazel_rules_go//go/config:goos, it must use a label without a workspace
    name if and only if the workspace is the main workspace.

    All Go build settings and transitions are in io_bazel_rules_go. So if
    io_bazel_rules_go is the main workspace (for development and testing),
    go_transition must use a label like //go/config:goos. If io_bazel_rules_go
    is not the main workspace (almost always), go_transition must use a label
    like @io_bazel_rules_go//go/config:goos.
    """
    if IS_RULES_GO and label.startswith("@io_bazel_rules_go"):
        return label[len("@io_bazel_rules_go"):]
    else:
        return label

def go_transition_wrapper(kind, transition_kind, name, **kwargs):
    """Wrapper for rules that may use transitions.

    This is used in place of instantiating go_binary or go_transition_binary
    directly. If one of the transition attributes is set explicitly, it
    instantiates the rule with a transition. Otherwise, it instantiates the
    regular rule. This prevents targets from being rebuilt for an alternative
    configuration identical to the default configuration.
    """
    transition_keys = ("goos", "goarch", "pure", "static", "msan", "race", "gotags", "linkmode")
    need_transition = any([key in kwargs for key in transition_keys])
    if need_transition:
        transition_kind(name = name, **kwargs)
    else:
        kind(name = name, **kwargs)

def go_transition_rule(**kwargs):
    """Like "rule", but adds a transition and mode attributes."""
    kwargs = dict(kwargs)
    kwargs["attrs"].update({
        "goos": attr.string(
            default = "auto",
            values = ["auto"] + {goos: None for goos, _ in GOOS_GOARCH}.keys(),
        ),
        "goarch": attr.string(
            default = "auto",
            values = ["auto"] + {goarch: None for _, goarch in GOOS_GOARCH}.keys(),
        ),
        "pure": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
        ),
        "static": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
        ),
        "msan": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
        ),
        "race": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
        ),
        "gotags": attr.string_list(default = []),
        "linkmode": attr.string(
            default = "auto",
            values = ["auto"] + LINKMODES,
        ),
        "_whitelist_function_transition": attr.label(
            default = "@bazel_tools//tools/whitelists/function_transition_whitelist",
        ),
    })
    kwargs["cfg"] = go_transition
    return rule(**kwargs)

def _go_transition_impl(settings, attr):
    # NOTE(bazelbuild/bazel#11409): Calling fail here for invalid combinations
    # of flags reports an error but does not stop the build.
    # In any case, get_mode should mainly be responsible for reporting
    # invalid modes, since it also takes --features flags into account.

    settings = dict(settings)

    _set_ternary(settings, attr, "static")
    race = _set_ternary(settings, attr, "race")
    msan = _set_ternary(settings, attr, "msan")
    pure = _set_ternary(settings, attr, "pure")
    if race == "on":
        if pure == "on":
            fail('race = "on" cannot be set when pure = "on" is set. race requires cgo.')
        pure = "off"
        settings[filter_transition_label("@io_bazel_rules_go//go/config:pure")] = False
    if msan == "on":
        if pure == "on":
            fail('msan = "on" cannot be set when msan = "on" is set. msan requires cgo.')
        pure = "off"
        settings[filter_transition_label("@io_bazel_rules_go//go/config:pure")] = False
    if pure == "on":
        race = "off"
        settings[filter_transition_label("@io_bazel_rules_go//go/config:race")] = False
        msan = "off"
        settings[filter_transition_label("@io_bazel_rules_go//go/config:msan")] = False
    cgo = pure == "off"

    goos = getattr(attr, "goos", "auto")
    goarch = getattr(attr, "goarch", "auto")
    _check_ternary("pure", pure)
    if goos != "auto" or goarch != "auto":
        if goos == "auto":
            fail("goos must be set if goarch is set")
        if goarch == "auto":
            fail("goarch must be set if goos is set")
        if (goos, goarch) not in GOOS_GOARCH:
            fail("invalid goos, goarch pair: {}, {}".format(goos, goarch))
        if cgo and (goos, goarch) not in CGO_GOOS_GOARCH:
            fail('pure is "off" but cgo is not supported on {} {}'.format(goos, goarch))
        platform = "@io_bazel_rules_go//go/toolchain:{}_{}{}".format(goos, goarch, "_cgo" if cgo else "")
        settings["//command_line_option:platforms"] = platform

    tags = getattr(attr, "gotags", [])
    if tags:
        tags_label = filter_transition_label("@io_bazel_rules_go//go/config:tags")
        settings[tags_label] = tags

    linkmode = getattr(attr, "linkmode", "auto")
    if linkmode != "auto":
        if linkmode not in LINKMODES:
            fail("linkmode: invalid mode {}; want one of {}".format(linkmode, ", ".join(LINKMODES)))
        linkmode_label = filter_transition_label("@io_bazel_rules_go//go/config:linkmode")
        settings[linkmode_label] = linkmode

    return settings

go_transition = transition(
    implementation = _go_transition_impl,
    inputs = [filter_transition_label(label) for label in [
        "//command_line_option:platforms",
        "@io_bazel_rules_go//go/config:static",
        "@io_bazel_rules_go//go/config:msan",
        "@io_bazel_rules_go//go/config:race",
        "@io_bazel_rules_go//go/config:pure",
        "@io_bazel_rules_go//go/config:tags",
        "@io_bazel_rules_go//go/config:linkmode",
    ]],
    outputs = [filter_transition_label(label) for label in [
        "//command_line_option:platforms",
        "@io_bazel_rules_go//go/config:static",
        "@io_bazel_rules_go//go/config:msan",
        "@io_bazel_rules_go//go/config:race",
        "@io_bazel_rules_go//go/config:pure",
        "@io_bazel_rules_go//go/config:tags",
        "@io_bazel_rules_go//go/config:linkmode",
    ]],
)

_reset_transition_dict = {
    "@io_bazel_rules_go//go/config:static": False,
    "@io_bazel_rules_go//go/config:msan": False,
    "@io_bazel_rules_go//go/config:race": False,
    "@io_bazel_rules_go//go/config:pure": False,
    "@io_bazel_rules_go//go/config:strip": False,
    "@io_bazel_rules_go//go/config:debug": False,
    "@io_bazel_rules_go//go/config:linkmode": LINKMODE_NORMAL,
    "@io_bazel_rules_go//go/config:tags": [],
}

_reset_transition_keys = sorted([filter_transition_label(label) for label in _reset_transition_dict.keys()])

def _go_reset_transition_impl(settings, attr):
    """Sets Go settings to default values so tools can be built safely.

    go_reset_transition sets all of the //go/config settings to their default
    values. This is used for tool binaries like nogo. Tool binaries shouldn't
    depend on the link mode or tags of the target configuration. This transition
    doesn't change the platform (goos, goarch), but tool binaries should also
    have `cfg = "exec"` so tool binaries should be built for the execution
    platform.
    """
    settings = dict(settings)
    for label, value in _reset_transition_dict.items():
        settings[filter_transition_label(label)] = value
    return settings

go_reset_transition = transition(
    implementation = _go_reset_transition_impl,
    inputs = _reset_transition_keys,
    outputs = _reset_transition_keys,
)

def _go_reset_target_impl(ctx):
    t = ctx.attr.dep[0]  # [0] seems to be necessary with the transition
    providers = [t[p] for p in [GoLibrary, GoSource, GoArchive]]

    # We can't pass DefaultInfo through as-is, since Bazel forbids executable
    # if it's a file declared in a different target. The caller must assume
    # that the first file is executable.
    default_info = t[DefaultInfo]
    default_info = DefaultInfo(
        files = default_info.files,
        data_runfiles = default_info.data_runfiles,
        default_runfiles = default_info.default_runfiles,
        executable = None,
    )
    providers.append(default_info)
    return providers

go_reset_target = rule(
    implementation = _go_reset_target_impl,
    attrs = {
        "dep": attr.label(
            mandatory = True,
            cfg = go_reset_transition,
        ),
        "_whitelist_function_transition": attr.label(
            default = "@bazel_tools//tools/whitelists/function_transition_whitelist",
        ),
    },
    doc = """Forwards providers from a target and applies go_reset_transition.

go_reset_target depends on a single target, built using go_reset_transition.
It forwards Go providers and DefaultInfo.

This is used to work around a problem with building tools: tools should be
built with 'cfg = "exec"' so they work on the execution platform, but we also
need to apply go_reset_transition, so for example, a tool isn't built as a
shared library with race instrumentation. This acts as an intermediately rule
so we can apply both transitions.
""",
)

def _check_ternary(name, value):
    if value not in ("on", "off", "auto"):
        fail('{}: must be "on", "off", or "auto"'.format(name))

def _set_ternary(settings, attr, name):
    value = getattr(attr, name, "auto")
    _check_ternary(name, value)
    if value != "auto":
        label = filter_transition_label("@io_bazel_rules_go//go/config:{}".format(name))
        settings[label] = value == "on"
    return value
