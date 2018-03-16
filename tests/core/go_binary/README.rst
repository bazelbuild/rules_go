Basic go_binary functionality
=============================

.. _go_binary: /go/core.rst#_go_binary

Tests to ensure that basic features of go_binary_ are working as expected.

.. contents::

output_path_test
----------------

Test that a go_binary_ rule with custom output path layouts generates expected
output filenames. It uses a Win32 target and verifies that mode or extension
can be dropped from the output path.
