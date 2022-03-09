Custom nogo analyzer flags
=====================

.. _nogo: /go/nogo.rst
.. _go_library: /docs/go/core/rules.md#_go_library

Tests to ensure that custom `nogo`_ analyzers that consume flags can be
supplied those flags via nono config.

.. contents::

flags_test
-----------
Verifies that a simple custom analyzer's behavior can be modified by setting
its analyzer flags in the nogo driver, and that these flags can be provided to
the driver via the nogo config `analyzer_flags` field. Also checks that
invalid flags as defined by the `flag` package cause the driver to immediately
return an error.

