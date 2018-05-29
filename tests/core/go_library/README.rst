Basic go_library functionality
==============================

.. _go_library: /go/core.rst#_go_library
.. #1520: https://github.com/bazelbuild/rules_go/issues/1520

empty
-----

Checks that a `go_library`_ will compile and link even if all the sources
(including assembly sources) are filtered out by build constraints.

asm_include
-----------

Checks that assembly files in a `go_library`_ may include other assembly
files in the same library. Verifies `#1520`_.
