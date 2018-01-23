Basic go_test functionality
===========================

.. _go_test: /go/core.rst#_go_test

Tests to ensure that basic features of go_test_ are working as expected.

.. contents::

internal_test
-------------

Test that a go_test_ rule that adds white box tests to an embedded package works.
This builds a library with `lib.go <lib.go>`_ and then a package with an
`internal test <internal_test.go>`_ that contains the test case.
It uses x_def stamped values to verify the library names are correct.

external_test
-------------

Test that a go_test_ rule that adds black box tests for a dependant package works.
This builds a library with `lib.go <lib.go>`_ and then a package with an
`external test <external_test.go>`_ that contains the test case.
It uses x_def stamped values to verify the library names are correct.

combined_test
-------------
Test that a go_test_ rule that adds both white and black box tests for a
package works.
This builds a library with `lib.go <lib.go>`_ and then a one merged with the
`internal test <internal_test.go>`_, and then another one that depends on it
with the `external test <external_test.go>`_.
It uses x_def stamped values to verify that all library names are correct.
Verifies #413

flag_test
---------
Test that a go_test_ rule that adds flags, even in the main package, can read
the flag.
This does not even build a library, it's a test in the main package with no
dependancies that checks it can declare and then read a flag.
Verifies #838