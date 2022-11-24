Custom nogo analyzers
=====================

.. _nogo: /go/nogo.rst
.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that custom `nogo`_ analyzers run and detect errors.

.. contents::

custom_test
-----------
Verifies that custom analyzers print errors and fail a `go_library`_ build when
a configuration file is not provided, and that analyzers with the same package
name do not conflict. Also checks that custom analyzers can be configured to
apply only to certain file paths using a custom configuration file.
