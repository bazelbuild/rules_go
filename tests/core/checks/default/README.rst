Default checker
===============

.. _go_library: /go/core.rst#_go_library

Tests to ensure that the default checker is working is generated when using
the core Go rules.

.. contents::

checker_error
-------------
Verifies that the default checker binary runs during bazel build by ensuring
that a build failure and error message are emitted when building a go_library_
target containing erroneous source code.
