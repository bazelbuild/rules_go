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

cc_libs_test
------------

Checks that Go binaries that include cgo code may or may not link against
libstdc++, depending on how they're linked. This tests several binaries:

* ``pure_bin`` - built in ``"pure"`` mode, should not depend on libstdc++.
* ``c_srcs`` - has no C++ code in sources, should not depend on libstdc++.
* ``cc_srcs`` - has some C++ code in sources, should depend on libstdc++.
* ``cc_deps`` - depends on a ``cc_library``, should depend on libstdc++
  because we don't know what's in it.

race_test
---------

Checks that cgo code in a binary with ``race = "on"`` is compiled in race mode.
Verifies #1592.
