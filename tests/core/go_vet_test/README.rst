Basic go_vet_test functionality
===============================

.. _go_vet_test: /go/core.rst#_go_vet_test
.. _go_test: /go/core.rst#_go_test

Tests to ensure that basic features of `go_vet_test`_ are working as expected.

.. contents::

internal_test
-------------
Tests nothing beyond what's already exercised by the `go_test`_ test suite,
but is necessary for further testing.

vet_lib
-------
Test that a simple `go_vet_test`_ rule executes successfully.

vet_internal_test
-----------------
Test that the `go_vet_test`_ rule correctly propagates the testonly flag.
