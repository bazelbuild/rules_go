nogo test with coverage
=======================

.. _nogo: /go/nogo.rst
.. _go_tool_library: /go/core.rst#_go_tool_library

Tests to ensure that `nogo`_ works with coverage.

coverage_target_test
--------------------
Checks that `nogo`_ works when coverage is enabled. All covered libraries gain
an implicit dependencies on ``//go/tools/coverdata``, which is a
`go_tool_library`_, which isn't built with `nogo`_. We should be able to
handle libraries like this that do not have serialized facts. Verifies #1940.
