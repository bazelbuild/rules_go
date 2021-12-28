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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "//go/private:mode.bzl",
    "LINKMODES",
    "LINKMODE_NORMAL",
)
load(
    "//go/private:platforms.bzl",
    "CGO_GOOS_GOARCH",
    "GOOS_GOARCH",
)
load(
    "//go/private:providers.bzl",
    "GoArchive",
    "GoLibrary",
    "GoSource",
)
load(
    "//go/platform:crosstool.bzl",
    "platform_from_crosstool",
)

def filter_transition_label(label):
    """Transforms transition labels for the current workspace.

    This works around bazelbuild/bazel#10499 by automatically using the correct
    way to refer to this repository (@io_bazel_rules_go from another workspace,
    but only repo-relative labels if this repository is the main workspace).
    """
    if label.startswith("//command_line_option:"):
        # This is a special prefix that allows transitions to access the values
        # of native command-line flags. It is not a valid package, but just a
        # syntactic prefix that is consumed by the transition logic, and thus
        # must not be passed through the Label constructor.
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/analysis/config/StarlarkDefinedConfigTransition.java;l=62;drc=463e8c80cd11d36777ddf80543aea7c53293f298
        return label
    else:
        return str(Label(label))

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
    crosstool_top = settings.pop("//command_line_option:crosstool_top")
    cpu = settings.pop("//command_line_option:cpu")
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
    else:
        # If not auto, try to detect the platform the inbound crosstool/cpu.
        platform = platform_from_crosstool(crosstool_top, cpu)
        if platform:
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

def _request_nogo_transition(settings, attr):
    """Indicates that we want the project configured nogo instead of a noop.

    This does not guarantee that the project configured nogo will be used (if
    bootstrap is true we are currently building nogo so that is a cyclic
    dependency).

    The config setting nogo_active requires bootstrap to be false and
    request_nogo to be true to provide the project configured nogo.
    """
    settings = dict(settings)
    settings[filter_transition_label("@io_bazel_rules_go//go/private:request_nogo")] = True
    return settings

request_nogo_transition = transition(
    implementation = _request_nogo_transition,
    inputs = [],
    outputs = [filter_transition_label(label) for label in [
        "@io_bazel_rules_go//go/private:request_nogo",
    ]],
)

go_transition = transition(
    implementation = _go_transition_impl,
    inputs = [filter_transition_label(label) for label in [
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
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
    "@io_bazel_rules_go//go/private:bootstrap_nogo": True,
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
    # if it's a file declared in a different target. To emulate that, symlink
    # to the original executable, if there is one.
    default_info = t[DefaultInfo]

    new_executable = None
    original_executable = default_info.files_to_run.executable
    default_runfiles = default_info.default_runfiles
    if original_executable:
        # In order for the symlink to have the same basename as the original
        # executable (important in the case of proto plugins), put it in a
        # subdirectory named after the label to prevent collisions.
        new_executable = ctx.actions.declare_file(paths.join(ctx.label.name, original_executable.basename))
        ctx.actions.symlink(
            output = new_executable,
            target_file = original_executable,
            is_executable = True,
        )
        default_runfiles = default_runfiles.merge(ctx.runfiles([new_executable]))

    providers.append(
        DefaultInfo(
            files = default_info.files,
            data_runfiles = default_info.data_runfiles,
            default_runfiles = default_runfiles,
            executable = new_executable,
        ),
    )
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
