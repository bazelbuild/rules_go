Nogo configuration
==================

.. _nogo: /go/nogo.rst
.. _go_binary: /docs/go/core/rules.md#_go_binary
.. _#1850: https://github.com/bazelbuild/rules_go/issues/1850
.. _#2470: https://github.com/bazelbuild/rules_go/issues/2470

Tests that verify nogo_ works on targets compiled in non-default configurations.

.. contents::

config_test
-----------

Verifies that a `go_binary`_ can be built in non-default configurations with
nogo. Verifies `#1850`_, `#2470`_.
