Import maps
===========

.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that importmap is working as expected.

.. contents::

importmap_test
--------------

Test that importmap declarations on go_library_ are propagated and obeyed.
This builds libraries using `src.go <src.go>`_ as multiple outputs with the differing importpaths,
adds identical importmap declarations and then checks that the libraries can be correctly imported
without colliding through differing intermediate libraries into `the main test <importmap_test.go>`_.
