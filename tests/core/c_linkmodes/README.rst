c-archive / c-shared linkmodes
==============================

.. _go_binary: /docs/go/core/rules.md#go_binary
.. _#2132: https://github.com/bazelbuild/rules_go/issues/2132
.. _#2138: https://github.com/bazelbuild/rules_go/issues/2138

Tests to ensure that c-archive link mode is working as expected.

.. contents::

c-archive_test
--------------

Checks that a ``go_binary`` can be built in ``c-archive`` mode and linked into
a C/C++ binary as a dependency.

c-archive_empty_hdr_test
------------------------

Checks that a ``go_binary`` built with in ``c-archive`` mode without cgo code
still produces an empty header file. Verifies `#2132`_.

c-shared_test
-------------

Checks that a ``go_binary`` can be built in ``c-shared`` mode and linked into
a C/C++ binary as a dependency.

c-shared_dl_test
----------------

Checks that a ``go_binary`` can be built in ``c-shared`` mode and loaded
dynamically from a C/C++ binary. The binary depends on a package in
``org_golang_x_crypto`` with a fair amount of assembly code. Verifies `#2138`_.
