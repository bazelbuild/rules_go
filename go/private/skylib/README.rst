This directory is a copy of github.com/bazelbuild/bazel-skylib/{lib,toolchains}
Version 0.8.0, retrieved on 2019-05-29, with the following changes:
- lib/BUILD is omitted
- all labels (e.g. in load() statements) are updated for this repository

This is needed only until nested workspaces works.
It has to be copied in because we use the functionality inside code that 
go_rules_dependencies itself depends on, which means we cannot automatically 
add the skylib dependency.
