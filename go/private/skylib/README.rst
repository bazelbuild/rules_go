This entire directory is a subset of the functionality in bazel-skylib
Individual modules are unmodified, but lib.bzl has had the paths changed, and 
not all modules are included.

This is needed only until nested workspaces works.
It has to be copied in because we use the functionality inside code that 
go_rules_dependencies itself depends on, which means we cannot automatically 
add the skylib dependancy.