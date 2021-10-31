Go Plugin supporting protobufs
==============================

.. _go_binary: /go/core.rst#_go_binary

Tests to ensure a protobuf can be included into a plugin and host.

all_test
--------

1. Test that a go_binary_ rule can write its shared object file with a custom
   name in the package directory (not the mode directory) when the plugin
   depends on a protobuf.

2. Test that a plugin with a protobuf dependency built using a go_binary_ rule
   can be loaded by a Go program and that its symbols are working as expected.
