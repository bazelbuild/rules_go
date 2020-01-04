This directory is a partial copy of github.com/bazelbuild/bazel-skylib/lib.
Version 0.5.0, retrieved on 2018-11-26.
Only versions.bzl is included.

versions.bzl is needed by repository rules imported from //go:deps.bzl.
Uses of Skylib outside of files loaded by //go:deps.bzl should use
the external Skylib repository, @bazel_skylib.
