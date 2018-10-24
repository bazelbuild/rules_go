Basic go_test functionality
===========================

.. _go_test: /go/core.rst#_go_test

Tests to ensure that basic features of `go_test`_ are working as expected.

.. contents::

internal_test
-------------

Test that a `go_test`_ rule that adds white box tests to an embedded package works.
This builds a library with `lib.go <lib.go>`_ and then a package with an
`internal test <internal_test.go>`_ that contains the test case.
It uses x_def stamped values to verify the library names are correct.

external_test
-------------

Test that a `go_test`_ rule that adds black box tests for a dependant package works.
This builds a library with `lib.go <lib.go>`_ and then a package with an
`external test <external_test.go>`_ that contains the test case.
It uses x_def stamped values to verify the library names are correct.

combined_test
-------------
Test that a `go_test`_ rule that adds both white and black box tests for a
package works.
This builds a library with `lib.go <lib.go>`_ and then a one merged with the
`internal test <internal_test.go>`_, and then another one that depends on it
with the `external test <external_test.go>`_.
It uses x_def stamped values to verify that all library names are correct.
Verifies #413

flag_test
---------
Test that a `go_test`_ rule that adds flags, even in the main package, can read
the flag.
This does not even build a library, it's a test in the main package with no
dependancies that checks it can declare and then read a flag.
Verifies #838

only_testmain_test
------------------
Test that an `go_test`_ that contains a ``TestMain`` function but no tests
still builds and passes.

external_importmap_test
----------------------

Test that an external test package in `go_test`_ is compiled with the correct
``importmap`` for the library under test. This is verified by defining an
interface in the library under test and implementing it in a separate
dependency.

Verifies #1538.

pwd_test
--------

Checks that the ``PWD`` environment variable is set to the current directory
in the generated test main before running a test. This matches functionality
in ``go test``.

Verifies #1561.

data_test
---------

Checks that data dependencies, including those inherited from ``deps`` and
``embed``, are visible to tests at run-time. Source files should not be
visible at run-time.
