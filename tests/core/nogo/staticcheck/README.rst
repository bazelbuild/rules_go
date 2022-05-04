Staticcheck analyzers test
=========

.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that staticcheck analyzers runs and detects errors.

.. contents::

statichcheck_test
--------
Verifies that staticcheck errors are emitted on a `go_library`_ with problems when built
with a ``nogo`` binary with staticcheck analyzers enabled. No errors should be emitted when
analyzing error-free source code.
