Basic cgo functionality
=======================

opts_test
---------

Checks that different sets of options are passed to C and C++ sources in a
``go_library`` with ``cgo = True``.

dylib_test
----------

Checks that Go binaries can link against dynamic C libraries. Some libraries
(especially those provided with ``cc_import``) may only have dynamic versions,
and we should be able to link against them and find them at run-time.
