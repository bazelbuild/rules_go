Building with standard libraries with missing .a files
===========

Tests to ensure that building with Go 1.20 and later versions of Go, which no longer
include precompiled standard library .a files, continues to work

build_stdlib_test
--------------

Test that a simple binary depending on a simple library can build when the WORKSPACE's
go version is set to 1.20rc1.