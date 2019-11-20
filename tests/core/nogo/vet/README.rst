Vet check
=========

.. _go_library: /go/core.rst#_go_library

Tests to ensure that vet runs and detects errors.

.. contents::

vet_test
--------
Verifies that vet errors are emitted on a `go_library`_ with problems when built
with a ``nogo`` binary with ``vet = True``. No errors should be emitted when
analyzing error-free source code. Vet should not be enabled by default.
