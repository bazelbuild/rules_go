Basic go_proto_library functionality
====================================

.. _go_proto_library: /proto/core.rst#_go_proto_library
.. _go_library: /go/core.rst#_go_library

Tests to ensure the basic features of `go_proto_library`_ are working.

.. contents::

embed_test
----------

Checks that `go_proto_library`_ can embed rules that provide `GoLibrary`_.

transitive_test
---------------

Checks that `go_proto_library`_ can import a proto dependency that is
embedded in a `go_library`_. Verifies #1422.
