Cross compilation
=================

.. _go_binary: /docs/go/core/rules.md#go_binary
.. _go_library: /docs/go/core/rules.md#go_library
.. _go_cross_binary: /docs/go/core/rules.md#go_cross_binary
.. _#2523: https://github.com/bazelbuild/rules_go/issues/2523

Tests to ensure that cross compilation is working as expected.

.. contents::

cross_test
----------


Tests that cross compilation controlled by the ``goos`` and ``goarch``
attributes on a `go_binary`_ produces executables for the correct platform.

This builds binaries using `main.go <main.go>`_ in multiple configurations, and
then passes them as data to a test `written in go <cross_test.go>`_.

The test executes the unix command "file" on the binaries to determine their
type, and checks they were built for the expected architecture.

The test also checks that `go_library`_ packages imoprted by `go_binary`_ with
``goos`` set are built in the correct configuration, and ``select`` is applied
in that configuration. Each binary depends on ``platform_lib``, which has a
different source file (determined by ``select``) for each platform. The source
files have a ``goos`` suffix, so they will only be built on the right platform.
If the wrong source file is used or if all files are filtered out, the
`go_binary`_ will not build.

go_cross_test
-------------

Indentical test to ``cross_test`` except tests using a `go_cross_binary`_ rule wrapping a `go_binary`_ instead of the ``goos`` and ``goarch`` attributes on a `go_binary`_.

sdk_version_test
----------------
Tests that a `go_binary`_ wrapped in a `go_cross_binary`_ rule, with the ``sdk_version`` attribute set, produces an executable built with the correct Go SDK version.

ios_select_test
---------------

Tests that we can cross-compile a library for iOS. We should be able to select
a dependency using ``@io_bazel_rules_go//go/platform:darwin``, which is true
when building for iOS (tested by ``ios_select_test``) and macOS
(tested by ``use_ios_lib``).

proto_test
----------

Tests that a ``go_proto_library`` can be cross-compiled, both with
``--platforms`` and with mode attributes.

no_context_info
---------------

Tests that a rule that uses ``@io_bazel_rules_go//go:toolchain`` but does not
depend on any other target can call ``go_context`` without error. Verifies
`#2523`_.
