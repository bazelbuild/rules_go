Basic -buildmode=plugin functionality
=====================================

.. _go_binary: /docs/go/core/rules.md#_go_binary

Tests to ensure the basic features of go_binary with linkmode="plugin" are
working as expected.

all_test
--------

1. Test that a go_binary_ rule can write its shared object file with a custom
   name in the package directory (not the mode directory).

2. Test that a plugin built using a go_binary_ rule can be loaded by a Go
   program and that its symbols are working as expected.
