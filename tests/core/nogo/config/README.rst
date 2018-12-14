Nogo configuration
==================

.. _nogo: /go/nogo.rst
.. _go_binary: /go/core.rst#_go_binary

Tests that verify nogo_ works on targets compiled in non-default configurations.

.. contents::

pure_aspect_test
----------------
Verifies that a `go_binary`_ with ``pure = "on"`` (compiled with the aspect)
builds successfully with nogo. Verifies #1850.
