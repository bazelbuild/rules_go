Deprecated functionality
========================

.. _proto: /proto/core.rst

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

Anything listed in here is functionality that is no longer supported, and will
be removed in a future version. Where possible these functions will also nag
you to remove them during the build.

.. contents:: :depth: 1

new_go_repository
~~~~~~~~~~~~~~~~~

**TODO**: More information

go_prefix
~~~~~~~~~

**TODO**: More information

go_proto_library
~~~~~~~~~~~~~~~~

There are two rules of the same name. This is specifically about the one in
:value:`"@io_bazel_rules_go//proto:go_proto_library.bzl"` which use mechanisms
that are not longer supported and not as flexible as the one you load from
:value:`"@io_bazel_rules_go//proto:def.bzl"` which is documented `here <proto>`_.

**TODO**: More information

cgo_library
~~~~~~~~~~~

**TODO**: More information

cgo_genrule
~~~~~~~~~~~

**TODO**: More information

go_repositories
~~~~~~~~~~~~~~~

**TODO**: More information
