Basic go_binary functionality
=============================

.. _go_binary: /go/core.rst#_go_binary

Tests to ensure the basic features of go_binary are working as expected.

hello
-----

Hello is a basic "hello world" program that doesn't do anything interesting.
Useful as a primitive smoke test -- if this doesn't build, nothing will.

out_test
--------

Test that a `go_binary`_ rule can write its executable file with a custom name
in the package directory (not the mode directory).
