Vet check
=========

.. _go_library: /go/core.rst#_go_library

Tests to ensure that vet runs and detects errors.

.. contents::

vet_enabled_no_errors
---------------------
Verifies that vet does not fail the build when analyzing error-free source code.

vet_enabled_has_errors
----------------------
Verifies that vet emits findings and fails a `go_library`_ build when analyzing
erroneous source code.

vet_default
-----------
Verifies that vet is disabled by default.
