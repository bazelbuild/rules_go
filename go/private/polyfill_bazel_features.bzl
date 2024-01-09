# bazel_features when used from a WORKSPACE rather than bzlmod context requires a two-step set-up (loading bazel_features, then calling a function from inside it).
# rules_go only has one-step set-up, and it would be a breaking change to require a second step.
# Accordingly, we supply a polyfill implementation of bazel_features which is only used when using rules_go from a WORKSPACE file,
# to avoid complicating code in rules_go itself.
# We just implement the checks we've seen we actually need, and hope to delete this completely when we are in a pure-bzlmod world.

_POLYFILL_BAZEL_FEATURES = """bazel_features = struct(
  cc = struct(
    find_cpp_toolchain_has_mandatory_param = {find_cpp_toolchain_has_mandatory_param},
  )
)
"""

def _polyfill_bazel_features_impl(rctx):
    # An empty string is treated as a "dev version", which is greater than anything.
    bazel_version = native.bazel_version or "999999.999999.999999"
    version_parts = bazel_version.split("-")[0].split(".")
    if len(version_parts) != 3:
        fail("invalid Bazel version '{}': got {} dot-separated segments, want 3".format(bazel_version, len(version_parts)))
    major_version_int = int(version_parts[0])
    minor_version_int = int(version_parts[1])

    find_cpp_toolchain_has_mandatory_param = major_version_int > 6 or (major_version_int == 6 and minor_version_int >= 1)

    rctx.file("BUILD.bazel", """exports_files(["features.bzl"])
""")
    rctx.file("features.bzl", _POLYFILL_BAZEL_FEATURES.format(
        find_cpp_toolchain_has_mandatory_param = repr(find_cpp_toolchain_has_mandatory_param),
    ))

polyfill_bazel_features = repository_rule(
    implementation = _polyfill_bazel_features_impl,
    # Force reruns on server restarts to keep native.bazel_version up-to-date.
    local = True,
)
