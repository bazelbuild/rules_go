nogo analyzers run against code using generics
==============================================

.. _nogo: /go/nogo.rst
.. _buildssa: https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/buildssa
.. _nilness: https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/nilness

Tests to ensure that `nogo`_ analyzers that run on code using generics get correct
type instantiation information.

.. contents::

generics_test
-------------

Verifies that code using generic types gets loaded including all type instantiation
information, so that analyzers based on the `buildssa`_ analyzer (such as `nilness`_) get
a complete picture of all types in the code.
