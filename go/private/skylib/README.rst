This directory is a partial copy of github.com/bazelbuild/bazel-skylib/lib.
Version 0.5.0, retrieved on 2018-11-26.
Only versions.bzl is included right now.

versions.bzl is needed by repository rules imported from //go:deps.bzl.
In particular, it's needed to check the minimum Bazel version and to choose
an implementation for io_bazel_rules_go_compat based on the Bazel version.

Uses of Skylib outside of files loaded by //go:deps.bzl should use
the external Skylib repository, @bazel_skylib.
