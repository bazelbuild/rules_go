nogo analyzers with dependencies
=============================

.. _nogo: /go/nogo.rst
.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that custom `nogo`_ analyzers that depend on each other are
run in the correct order.

.. contents::

deps_test
---------
Given the following dependency graph of analyzers:

    a ----+
          |
          v
    b --> c --> d

Where analyzers a, b, c are explicitly depended on by the `nogo`_ rule and d
isn't, verifies that a `go_library`_ build causes both paths in the graph
(a->c->d and b->c->d) to be executed, and that each analyzer runs exactly once.

Also verify that the diagnostics reported by d are not printed to the build log
since d was not explicitly depended on by the declared `nogo`_ rule.
