Go providers
============

.. _providers: https://docs.bazel.build/versions/master/skylark/rules.html#providers

.. _go_library: core.rst#go_library
.. _go_binary: core.rst#go_binary
.. _go_test: core.rst#go_test
.. _cc_library: https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library
.. _flatbuffers: http://google.github.io/flatbuffers/
.. _static linking: modes.rst#building-static-binaries
.. _race detector: modes.rst#using-the-race-detector
.. _runfiles: https://docs.bazel.build/versions/master/skylark/lib/runfiles.html

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**


The providers_ are the outputs of the rules, you generaly get them by having a dependency on a rule,
and then asking for a provider of a specific type.

.. contents:: :depth: 2

-----

Design
------

The Go providers are designed primarily for the efficiency of the Go rules, the information they
share is mostly there because it is required for the core rules to work.

All the providers are designed to hold only immutable data. This is partly because its a cleaner
design choice to be able to assume a provider will never change, but also because only immutable
objects are allowed to be stored in a depset, and it's really useful to have depsets of providers.
Specifically the :param:`direct` and :param:`transitive` fields on GoLibrary_ only work because
it is immutable.

API
---

GoLibrary
~~~~~~~~~

This is the provider exposed by the go_library_ rule, or anything that wants to behave like one.
It provides all the information requried to use the library as a dependency, for other libraries,
binaries or tests.

+--------------------------------+-----------------------------------------------------------------+
| **Name**                       | **Type**                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`importpath`            | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The import path for this library.                                                                |
+--------------------------------+-----------------------------------------------------------------+
| :param:`direct`                | :type:`depset(GoLibrary)`                                       |
+--------------------------------+-----------------------------------------------------------------+
| The direct depencancies of the library.                                                          |
+--------------------------------+-----------------------------------------------------------------+
| :param:`transitive`            | :type:`depset(GoLibrary)`                                       |
+--------------------------------+-----------------------------------------------------------------+
| The full transitive set of Go libraries depended on.                                             |
+--------------------------------+-----------------------------------------------------------------+
| :param:`srcs`                  | :type:`depset(File)`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The original sources used to build the library.                                                  |
+--------------------------------+-----------------------------------------------------------------+
| :param:`cover_vars`            | :type:`tuple(String)`                                           |
+--------------------------------+-----------------------------------------------------------------+
| The cover variables added to this library.                                                       |
+--------------------------------+-----------------------------------------------------------------+
| :param:`cgo_deps`              | :type:`depset(cc_library)`                                      |
+--------------------------------+-----------------------------------------------------------------+
| The direct cgo dependencies of this library.                                                     |
| This has the same constraints as things that can appear in the deps of a cc_library_.            |
+--------------------------------+-----------------------------------------------------------------+
| :param:`runfiles`              | runfiles_                                                       |
+--------------------------------+-----------------------------------------------------------------+
| The files needed to run anything that includes this library.                                     |
+--------------------------------+-----------------------------------------------------------------+


GoEmbed
~~~~~~~

GoEmbed is a provider designed to be used as the output of anything that provides Go code, and an
input to anything that compiles Go code.
It combines the source with dependencies that source will require.

There are two main uses for this.

#. Recompiling a library with additional sources.
   go_library_ returns a GoEmbed provider with the transformed sources and deps that it was
   consuming.
   go_test_ uses this to recompile the library with additional test files, to build the test
   version of the library. You can use the same feature to recompile a proto library with
   additional sources that were not generated by the proto compiler.

#. Providing the dependencies for generated code.
   If you wanted to use flatbuffers_ in your code, and you had a custom rule that ran the
   flatbuffers compiler to generate the serialization functions, you might hit the issue that
   the only thing that knows you depend on ``github.com/google/flatbuffers/go`` is the generated
   code.
   You can instead have the generator return a GoEmbed provider instead of just the generated
   files, allowing you to tie the generated files to the additional dependencies they add to
   any package trying to compile them.

+--------------------------------+-----------------------------------------------------------------+
| **Name**                       | **Type**                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`srcs`                  | :type:`depset(File)`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The original sources for this library before transformations like cgo and coverage.              |
+--------------------------------+-----------------------------------------------------------------+
| :param:`build_srcs`            | :type:`depset(File)`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The sources that are actually compiled after transformations like cgo and coverage.              |
+--------------------------------+-----------------------------------------------------------------+
| :param:`deps`                  | :type:`depset(GoLibrary)`                                       |
+--------------------------------+-----------------------------------------------------------------+
| The direct dependencies needed by the :param:`srcs`.                                             |
+--------------------------------+-----------------------------------------------------------------+
| :param:`cover_vars`            | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The cover variables used in these sources.                                                       |
+--------------------------------+-----------------------------------------------------------------+
| :param:`cgo_deps`              | :type:`depset(cc_library)`                                      |
+--------------------------------+-----------------------------------------------------------------+
| The direct cgo dependencies of this library.                                                     |
+--------------------------------+-----------------------------------------------------------------+
| :param:`gc_goopts`             | :type:`tuple(string)`                                           |
+--------------------------------+-----------------------------------------------------------------+
| Go compilation options that should be used when compiling these sources.                         |
| In general these will be used for *all* sources of any library this provider is embedded into.   |
+--------------------------------+-----------------------------------------------------------------+


GoArchive
~~~~~~~~~

GoArchive is a provider that exposes a compiled library.

+--------------------------------+-----------------------------------------------------------------+
| **Name**                       | **Type**                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`lib`                   | :type:`compiled archive file`                                   |
+--------------------------------+-----------------------------------------------------------------+
| The archive file representing the library compiled in a specific :param:`mode` ready for linking |
| into binaries.                                                                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`searchpath`            | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The search path entry under which the :param:`lib` would be found.                               |
+--------------------------------+-----------------------------------------------------------------+
| :param:`mode`                  | :type:`Mode`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| The mode the library was compiled in.                                                            |
+--------------------------------+-----------------------------------------------------------------+
