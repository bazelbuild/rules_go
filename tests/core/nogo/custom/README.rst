Custom nogo analyzers
=====================

.. _nogo: /go/nogo.rst
.. _go_library: /go/core.rst#_go_library

Tests to ensure that custom `nogo`_ analyzers run and detect errors.

.. contents::

custom_analyzers_default_config
-------------------------------
Verifies that custom analyzers print errors and fail a `go_library`_ build when
a configuration file is not provided, and that analyzers with the same package
name do not conflict.

custom_analyzers_custom_config
------------------------------
Verifies that custom analyzers can be configured to apply only to certain file
paths using a custom configuration file, and that analyzers with the same
package name do not conflict.

custom_analyzers_no_errors
--------------------------
Verifies that a library build succeeds if custom analyzers do not find any
errors in the library's source code, and that analyzers with the same package
name do not conflict.
