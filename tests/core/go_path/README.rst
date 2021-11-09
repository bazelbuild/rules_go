Basic go_path functionality
===========================

.. _go_path: /docs/go/core/rules.md#_go_path

Tests to ensure the basic features of `go_path`_ are working as expected.

go_path_test
------------

Consumes `go_path`_ rules built for the same set of packages in archive, copy,
and link modes and verifies that expected files are present in each mode.
