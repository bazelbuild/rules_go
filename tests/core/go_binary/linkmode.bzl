_LINKMODE_SETTING = "//go/config:linkmode"

def _linkmode_pie_transition_impl(settings, attr):
    return {
        _LINKMODE_SETTING: "pie",
    }

_linkmode_pie_transition = transition(
    implementation = _linkmode_pie_transition_impl,
    inputs = [_LINKMODE_SETTING],
    outputs = [_LINKMODE_SETTING],
)

def _linkmode_pie_wrapper(ctx):
    in_binary = ctx.attr.target[0][DefaultInfo].files.to_list()[0]
    out_binary = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(output = out_binary, target_file = in_binary)
    return [
        DefaultInfo(
            files = depset([out_binary]),
        ),
    ]

linkmode_pie_wrapper = rule(
    implementation = _linkmode_pie_wrapper,
    doc = """Provides the (only) file produced by target, but after transitioning the linkmode setting to PIE.""",
    attrs = {
        "target": attr.label(
            cfg = _linkmode_pie_transition,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
