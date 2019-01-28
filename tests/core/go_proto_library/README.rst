Basic go_proto_library functionality
====================================

.. _go_proto_library: /proto/core.rst#_go_proto_library
.. _go_library: /go/core.rst#_go_library
.. _#1422: https://github.com/bazelbuild/rules_go/issues/1422
.. _#1596: https://github.com/bazelbuild/rules_go/issues/1596

Tests to ensure the basic features of `go_proto_library`_ are working.

.. contents::

embed_test
----------

Checks that `go_proto_library`_ can embed rules that provide `GoLibrary`_.

transitive_test
---------------

Checks that `go_proto_library`_ can import a proto dependency that is
embedded in a `go_library`_. Verifies `#1422`_.

adjusted_import_test
--------------------

Checks that `go_proto_library`_ can build ``proto_library`` with
``import_prefix`` and ``strip_import_prefix``.

gofast_test and gofast_grpc_test
--------------------------------

Checks that the gogo `gofast` compiler plugins build and link.  In
particular, these plugins only depoend on `github.com/golang/protobuf`.

gogofast_test and gogofast_grpc_test
------------------------------------

Checks that the `gogofast` compiler plugins build and link.  In
particular, these plugins depend on both `github.com/gogo/protobuf`
and `github.com/golang/protobuf`.

proto_package_test
------------------

Checks that `go_proto_library`_ generates files with a package name based on
the proto package, not ``importpath`` when ``option go_package`` is not given.
Verifies `#1596`_.
