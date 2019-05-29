This directory is a copy of github.com/bazelbuild/bazel-skylib/lib.
Version 0.5.0 (retrieved on 2018-11-26) + some changes:
- cherry-picked Skylib's daf513702286fe211f291675443235e35e79f34f, except for
  the files in "tests"
- updated labels in load() statements and toolchain references

This is needed only until nested workspaces works.
It has to be copied in because we use the functionality inside code that 
go_rules_dependencies itself depends on, which means we cannot automatically 
add the skylib dependency.
