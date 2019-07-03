.. _#2067: https://github.com/bazelbuild/rules_go/issues/2067

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

dylib_test
----------

Checks that Go binaries can link against dynamic C libraries that are only
available as a versioned shared library, like ``libfoo.so.1``.

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

tag_test
--------

Checks that sources with ``// +build cgo`` are built when cgo is enabled
(whether or not ``cgo = True`` is set), and sources with ``// +build !cgo``
are only built in pure mode.

cdeps_link_test
---------------

Checks that libraries in ``cdeps`` are linked into the generated ``_cgo_.o``
executable used to produce ``_cgo_imports.go``. Verifies `#2067`_.
