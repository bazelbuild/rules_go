Executable name
===============

.. _go_binary: /docs/go/core/rules.md#go_binary

The filename of the executable produced by a go_binary_ rule is unpredictale, the full path includes
the compilation mode amongst other things, and the rules offer no backwards compatibility guarantees
about the filename.
For the simple case where you know exactly what you want the output filename to be, you can use a
genrule to copy it to a well known place.
