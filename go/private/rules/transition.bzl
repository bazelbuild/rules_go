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

# A list of rules_go settings that are possibly set by go_transition.
# Keep their package name in sync with the implementation of
# _original_setting_key.
TRANSITIONED_GO_SETTING_KEYS = [
    filter_transition_label(key)
    for key in [
        "//go/config:static",
        "//go/config:msan",
        "//go/config:race",
        "//go/config:pure",
        "//go/config:linkmode",
        "//go/config:tags",
    ]
]

def _original_setting_key(key):
    if not "//go/config:" in key:
        fail("_original_setting_key currently assumes that all Go settings live under //go/config, got: " + key)
    name = key.split(":")[1]
    return filter_transition_label("//go/private/rules:original_" + name)

_SETTING_KEY_TO_ORIGINAL_SETTING_KEY = {
    setting: _original_setting_key(setting)
    for setting in TRANSITIONED_GO_SETTING_KEYS
}

def _go_transition_impl(settings, attr):
    # NOTE: Keep the list of rules_go settings set by this transition in sync
    # with POTENTIALLY_TRANSITIONED_SETTINGS.
    #
    # NOTE(bazelbuild/bazel#11409): Calling fail here for invalid combinations
    # of flags reports an error but does not stop the build.
    # In any case, get_mode should mainly be responsible for reporting
    # invalid modes, since it also takes --features flags into account.

    original_settings = settings
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

    for key, original_key in _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.items():
        old_value = original_settings[key]
        value = settings[key]

        # If the outgoing configuration would differ from the incoming one in a
        # value, record the old value in the special original_* key so that the
        # real setting can be reset to this value before the new configuration
        # would cross a non-deps dependency edge.
        if value != old_value:
            # Encoding as JSON makes it possible to embed settings of arbitrary
            # types (currently bool, string and string_list) into a single type
            # of setting (string) with the information preserved whether the
            # original setting wasn't set explicitly (empty string) or was set
            # explicitly to its default  (always a non-empty string with JSON
            # encoding, e.g. "\"\"" or "[]").
            settings[original_key] = json.encode(old_value)
        else:
            settings[original_key] = ""

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
    ] + TRANSITIONED_GO_SETTING_KEYS],
    outputs = [filter_transition_label(label) for label in [
        "//command_line_option:platforms",
    ] + TRANSITIONED_GO_SETTING_KEYS + _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.values()],
)

_common_reset_transition_dict = dict({
    "@io_bazel_rules_go//go/config:static": False,
    "@io_bazel_rules_go//go/config:msan": False,
    "@io_bazel_rules_go//go/config:race": False,
    "@io_bazel_rules_go//go/config:pure": False,
    "@io_bazel_rules_go//go/config:strip": False,
    "@io_bazel_rules_go//go/config:debug": False,
    "@io_bazel_rules_go//go/config:linkmode": LINKMODE_NORMAL,
    "@io_bazel_rules_go//go/config:tags": [],
}, **{setting: "" for setting in _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.values()})

_reset_transition_dict = dict(_common_reset_transition_dict, **{
    "@io_bazel_rules_go//go/private:bootstrap_nogo": True,
})

_reset_transition_keys = sorted([filter_transition_label(label) for label in _reset_transition_dict.keys()])

def _go_tool_transition_impl(settings, attr):
    """Sets most Go settings to default values (use for external Go tools).

    go_tool_transition sets all of the //go/config settings to their default
    values and disables nogo. This is used for Go tool binaries like nogo
    itself. Tool binaries shouldn't depend on the link mode or tags of the
    target configuration and neither the tools nor the code they potentially
    generate should be subject to nogo's static analysis. This transition
    doesn't change the platform (goos, goarch), but tool binaries should also
    have `cfg = "exec"` so tool binaries should be built for the execution
    platform.
    """
    settings = dict(settings)
    for label, value in _reset_transition_dict.items():
        settings[filter_transition_label(label)] = value
    return settings

go_tool_transition = transition(
    implementation = _go_tool_transition_impl,
    inputs = _reset_transition_keys,
    outputs = _reset_transition_keys,
)

def _non_go_tool_transition_impl(settings, attr):
    """Sets all Go settings to default values (use for external non-Go tools).

    non_go_tool_transition sets all of the //go/config settings as well as the
    nogo settings to their default values. This is used for all tools that are
    not themselves targets created from rules_go rules and thus do not read
    these settings. Resetting all of them to defaults prevents unnecessary
    configuration changes for these targets that could cause rebuilds.

    Examples: This transition is applied to attributes referencing proto_library
    targets or protoc directly.
    """
    settings = dict(settings)
    for label, value in _reset_transition_dict.items():
        settings[filter_transition_label(label)] = value
    settings[filter_transition_label("@io_bazel_rules_go//go/private:bootstrap_nogo")] = False
    return settings

non_go_tool_transition = transition(
    implementation = _non_go_tool_transition_impl,
    inputs = _reset_transition_keys,
    outputs = _reset_transition_keys,
)

def _go_reset_target_impl(ctx):
    t = ctx.attr.dep[0]  # [0] seems to be necessary with the transition
    providers = [t[p] for p in [GoLibrary, GoSource, GoArchive] if p in t]

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
            cfg = go_tool_transition,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = """Forwards providers from a target and applies go_tool_transition.

go_reset_target depends on a single target, built using go_tool_transition. It
forwards Go providers and DefaultInfo.

This is used to work around a problem with building tools: Go tools should be
built with 'cfg = "exec"' so they work on the execution platform, but we also
need to apply go_tool_transition so that e.g. a tool isn't built as a shared
library with race instrumentation. This acts as an intermediate rule that allows
to apply both both transitions.
""",
)

non_go_reset_target = rule(
    implementation = _go_reset_target_impl,
    attrs = {
        "dep": attr.label(
            mandatory = True,
            cfg = non_go_tool_transition,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = """Forwards providers from a target and applies non_go_tool_transition.

non_go_reset_target depends on a single target, built using
non_go_tool_transition. It forwards Go providers and DefaultInfo.

This is used to work around a problem with building tools: Non-Go tools should
be built with 'cfg = "exec"' so they work on the execution platform, but they
also shouldn't be affected by Go-specific config changes applied by
go_transition.
""",
)

def _non_go_transition_impl(settings, attr):
    """Sets all Go settings to the values they had before the last go_transition.

    non_go_transition sets all of the //go/config settings to the value they had
    before the last go_transition. This should be used on all attributes of
    go_library/go_binary/go_test that are built in the target configuration and
    do not constitute advertise any Go providers.

    Examples: This transition is applied to the 'data' attribute of go_binary so
    that other Go binaries used at runtime aren't affected by a non-standard
    link mode set on the go_binary target, but still use the same top-level
    settings such as e.g. race instrumentation.
    """
    new_settings = {}
    for key, original_key in _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.items():
        original_value = settings[original_key]
        if original_value:
            # Reset to the original value of the setting before go_transition.
            new_settings[key] = json.decode(original_value)
        else:
            new_settings[key] = settings[key]

        # Reset the value of the helper setting to its default for two reasons:
        # 1. Performance: This ensures that the Go settings of non-Go
        #    dependencies have the same values as before the go_transition,
        #    which can prevent unnecessary rebuilds caused by configuration
        #    changes.
        # 2. Correctness in edge cases: If there is a path in the build graph
        #    from a go_binary's non-Go dependency to a go_library that does not
        #    pass through another go_binary (e.g., through a custom rule
        #    replacement for go_binary), this transition could be applied again
        #    and cause incorrect Go setting values.
        new_settings[original_key] = ""

    return new_settings

non_go_transition = transition(
    implementation = _non_go_transition_impl,
    inputs = TRANSITIONED_GO_SETTING_KEYS + _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.values(),
    outputs = TRANSITIONED_GO_SETTING_KEYS + _SETTING_KEY_TO_ORIGINAL_SETTING_KEY.values(),
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

_SDK_VERSION_BUILD_SETTING = filter_transition_label("@io_bazel_rules_go//go/toolchain:sdk_version")
TRANSITIONED_GO_CROSS_SETTING_KEYS = [
    _SDK_VERSION_BUILD_SETTING,
    "//command_line_option:platforms",
]

def _go_cross_transition_impl(settings, attr):
    settings = dict(settings)
    if attr.sdk_version != None:
        settings[_SDK_VERSION_BUILD_SETTING] = attr.sdk_version

    if attr.platform != None:
        settings["//command_line_option:platforms"] = str(attr.platform)

    return settings

go_cross_transition = transition(
    implementation = _go_cross_transition_impl,
    inputs = TRANSITIONED_GO_CROSS_SETTING_KEYS,
    outputs = TRANSITIONED_GO_CROSS_SETTING_KEYS,
)
