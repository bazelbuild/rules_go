Nolint check
=========

.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that errors found by nogo and annotated with //nolint are
ignored.

.. contents::

nolint_test
--------
Verified that errors emitted by ``nogo`` are ignored when `//nolint` appears as
a comment.
