Runfiles functionality
=====================

runfiles_tests
--------------

Checks that functions in ``//go/tools/bazel:go_default_library`` that
provide access to runfiles behave correctly. In particular, this checks:

* ``Runfile`` works for regular files.
* ``FindBinary`` works for binaries.
* ``ListRunfiles`` lists all expected files.
* These functions work for runfiles in the local workspace and for files in
  external repositories (``@runfiles_remote_test`` is a ``local_repository``
  that points to a subdirectory here).
* These functions work in tests invoked with ``bazel test`` and
  binaries invoked with ``bazel run``.
* These functions work on Windows and other platforms. Bazel doesn't
  create a symlink tree for runfiles on Windows since symbolic links
  can't be created without administrative privilege by default.

TODO: Verify binary behavior in CI. The ``local_bin`` and ``remote_bin``
targets verify behavior for binaries, but they are not tests.
