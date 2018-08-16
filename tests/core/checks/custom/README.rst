Custom checks
=============

.. _go_library: /go/core.rst#_go_library

Tests to ensure that custom build-time code analysis checks run and detect
errors.

.. contents::

custom_checks_default_config
----------------------------
Verifies that custom checks print errors and fail a go_library build when a
configuration file is not provided.

custom_checks_custom_config
---------------------------
Verifies that custom checks can be configured to apply only to certain file
paths using a custom configuration file.

custom_checks_no_errors
------------------------
Verifies that a library build succeeds if custom checks do not find any errors
in the library's source code.
