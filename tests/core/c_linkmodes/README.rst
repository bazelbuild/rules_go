c-archive / c-shared linkmodes
==============================

.. _go_binary: /go/core.rst#go_binary

Tests to ensure that c-archive link mode is working as expected.

.. contents::

add_test_archive.c
------------------

Test that calls a CGo exported `GoAdd` method from C and check that the return
value is correct. This is a `cc_test` that links statically against a
`go_binary`.

add_test_shared.c
-----------------

Test that calls a CGo exported `GoAdd` method from C and check that the return
value is correct. This is a `cc_test` that links dynamically against a
`go_binary`.

crypto_test_dl.c
-----------------------

Test that calls a CGo exported `GoFn` method that depends on a function from
golang.org/x/crypto. This is a `cc_test` that loads the CGo shared library
dynamically.
