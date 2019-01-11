This directory is a copy of github.com/bazelbuild/bazel-skylib/lib.
Version 0.5.0, retrieved on 2018-11-26.

This is needed only until nested workspaces works.
It has to be copied in because we use the functionality inside code that 
go_rules_dependencies itself depends on, which means we cannot automatically 
add the skylib dependency.
