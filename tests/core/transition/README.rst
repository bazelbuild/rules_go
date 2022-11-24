Misc configuration transition tests
===================================

.. _go_binary: /docs/go/core/rules.md#_go_binary
.. _go_test: /docs/go/core/rules.md#_go_test

Tests that check that configuration transitions for `go_binary`_ and `go_test`_
are working correctly.

Most tests for specific attributes are in other directories, for example,
``c_linkmodes``, ``cross``, ``nogo``, ``race``. This directory covers
transition-related stuff that doesn't fit anywhere else.

cmdline_test
------------
Tests that build settings can be set with flags on the command line. The test
builds a target with and without a command line flag and verifies the output
is different.
