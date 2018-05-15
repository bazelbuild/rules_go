Custom checks
=============

.. _go_library: /go/core.rst#_go_library

Tests to ensure that custom build-time code analysis checks run and detect
errors.

.. contents::

custom_check_errors
-------------------
Verifies that a multiple (2) custom checks successfully reports errors while
building a library and causes a build failure.

custom_check_no_errors
----------------------
Verifies that a multiple (2) custom checks do not find errors while building a
library and allows that build to succeed.
