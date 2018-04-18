stdlib functionality
====================

buildid_test
------------

Checks that the ``stdlib`` rule builds archives without Go build ids.

Go build ids are used for caching within ``go build``; they are not needed by
Bazel, which has its own caching mechanism. The build id is influenced by
all inputs to the build, including cgo environment variables. Since these
variables may include sandbox paths, they can make the build id
non-reproducible, even though they don't affect the final binary.
