symbol stripping
====================

strip_test
---------

Tests that the global Bazel configuration for stripping are applied to go_binary
targets.
In particular, it tests that stripping is performed iff the bazel flag ``--strip``
is set to ``always`` or ``--strip`` is set to ``sometimes`` and ``--compilation_mode``
is ``fastbuild``.
Additionally, it tests that stack traces still contain the same information when stripping
is enabled.
