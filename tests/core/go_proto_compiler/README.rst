Basic go_proto_compiler functionality
=====================================

.. _go_proto_compiler: /proto/core.rst#_go_proto_compiler
.. _#2704: https://github.com/bazelbuild/rules_go/issues/2704

Tests to ensure the basic features of `go_proto_compiler`_ are working.

.. contents::

executable_runfiles_test
------------------------

Checks that the `plugin` executable of `go_proto_compiler` has access to its `data` runfiles when the compile action is run.
Verifies `#2704`_.
