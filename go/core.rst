Core go rules
=============

.. _test_filter: https://bazel.build/versions/master/docs/bazel-user-manual.html#flag--test_filter
.. _test_arg: https://bazel.build/versions/master/docs/bazel-user-manual.html#flag--test_arg
.. _gazelle: tools/gazelle/README.rst
.. _build constraints: http://golang.org/pkg/go/build/
.. _GoLibrary: providers.rst#GoLibrary
.. _GoSource: providers.rst#GoSource
.. _GoArchive: providers.rst#GoArchive
.. _cgo: http://golang.org/cmd/cgo/
.. _"Make variable": https://docs.bazel.build/versions/master/be/make-variables.html
.. _Bourne shell tokenization: https://docs.bazel.build/versions/master/be/common-definitions.html#sh-tokenization
.. _data dependencies: https://docs.bazel.build/versions/master/build-ref.html#data
.. _cc library deps: https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library.deps
.. _pure: modes.rst#pure
.. _static: modes.rst#static
.. _goos: modes.rst#goos
.. _goarch: modes.rst#goarch
.. _mode attributes: modes.rst#mode-attributes

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

These are the core go rules, required for basic operation.
The intent is that theses rules are sufficient to match the capabilities of the normal go tools.

.. contents:: :depth: 2

-----

Design
------

Defines and stamping
~~~~~~~~~~~~~~~~~~~~

In order to make it possible to provide build time information to go code without data files, we
support the concept of stamping.

Stamping asks the linker to substitute the inital value of a global string variable with
a new value. It only happens at link time, not compile, so it happens at the level of a go binary
not a package. This means that changing a value results only in re-linking, not re-compilation
and thus does not cause cascading changes.

You specify the values to substitute in the x_defs parameter to any of the go rules.
This is a map of string to string, where the key is the name of the variable to substitute and the
value is the value to use.
If the key is not a fully qualified name, then the current package is used.
These mappings are collected up across the entire transitive dependancies of a binary, and then
applied, which means you can set a define on a library, and it will be applied in any binary that
links in that library. You can also override a the value of any libraries stamping from the x_defs
of the binary if needed.

Embedding
~~~~~~~~~

This is used for things like internal tests, where a library is recompiled with additional sources
and also code generators where the generated source will be known to have extra dependencies.

**TODO**: More information

API
---

go_library
~~~~~~~~~~

This builds a Go library from a set of source files that are all part of
the same package.

Providers
^^^^^^^^^

* GoLibrary_
* GoSource_
* GoArchive_

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
|                                                                                                  |
| To interoperated cleanly with gazelle_ right now this should be :value:`go_default_library`.     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this library. If unspecified, the library will have an implicit               |
| dependency on ``//:go_prefix``, and the import path will be derived from the prefix              |
| and the library's label.                                                                         |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of Go source files that are compiled to create the package.                             |
| Only :value:`.go` files are permitted, unless the cgo attribute is set, in which case the        |
| following file types are permitted: :value:`.go, .c, .s, .S .h`.                                 |
| The files may contain Go-style `build constraints`_.                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`x_defs`            | :type:`string_dict`         | :value:`{}`                           |
+----------------------------+-----------------------------+---------------------------------------+
| Map of defines to add to the go link command.                                                    |
| See `Defines and stamping`_ for examples of how to use these.                                    |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this library imports directly.                                              |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`embed`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this test library directly.                                                 |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
| These can provide both :param:`srcs` and :param:`deps` to this library.                          |
| See Embedding_ for more information about how and when to use this.                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_goopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go compilation command when using the gc compiler.                   |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cgo`               | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True`, the package uses cgo_.                                                         |
| The cgo tool permits Go code to call C code and vice-versa.                                      |
| This does not support calling C++.                                                               |
| When cgo is set, :param:`srcs` may contain C or assembly files; these files are compiled with    |
| the normal c compiler and included in the package.                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cdeps`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of other libraries that the c code depends on.                                          |
| This can be anything that would be allowed in `cc library deps`_                                 |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`copts`             | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C compilation command.                                               |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`clinkopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C link command.                                                      |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+

Example
^^^^^^^

.. code:: bzl

  go_library(
      name = "go_default_library",
      srcs = [
          "foo.go",
          "bar.go",
      ],
      deps = [
          "//tools:go_default_library",
          "@org_golang_x_utils//stuff:go_default_library",
      ],
      importpath = "github.com/example/project/foo",
      visibility = ["//visibility:public"],
  )

go_binary
~~~~~~~~~

This builds an executable from a set of source files, which must all be
in the ``main`` package. You can run the binary with ``bazel run``, or you can
build it with ``bazel build`` and run it directly.

Providers
^^^^^^^^^

* GoLibrary_
* GoSource_
* GoArchive_

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
|                                                                                                  |
| This should be named the same as the desired name of the generated binary .                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this binary. If unspecified, the binary will have an implicit                 |
| dependency on ``//:go_prefix``, and the import path will be derived from the prefix              |
| and the binary's label.                                                                          |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of Go source files that are compiled to create the binary.                              |
| Only :value:`.go` files are permitted, unless the cgo attribute is set, in which case the        |
| following file types are permitted: :value:`.go, .c, .s, .S .h`.                                 |
| The files may contain Go-style `build constraints`_.                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this binary imports directly.                                               |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`embed`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this binary embeds directly.                                                |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
| These can provide both :param:`srcs` and :param:`deps` to this binary.                           |
| See Embedding_ for more information about how and when to use this.                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`pure`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to link in pure_ mode.               |
| It should be one of :value:`on`, :value:`off` or :value:`auto`.                                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`static`            | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to link in static_ mode.             |
| It should be one of :value:`on`, :value:`off` or :value:`auto`.                                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goos`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goos_ to compile and link for.         |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrideds the default as set by the current    |
| target platform, and allows for single builds to make binaries for multiple architectures.       |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goarch`            | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goarch_ to compile and link for.       |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrideds the default as set by the current    |
| target platform, and allows for single builds to make binaries for multiple architectures.       |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_goopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go compilation command when using the gc compiler.                   |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_linkopts`       | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go link command when using the gc compiler.                          |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`x_defs`            | :type:`string_dict`         | :value:`{}`                           |
+----------------------------+-----------------------------+---------------------------------------+
| Map of defines to add to the go link command.                                                    |
| See `Defines and stamping`_ for examples of how to use these.                                    |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cgo`               | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True`, the binary uses cgo_.                                                          |
| The cgo tool permits Go code to call C code and vice-versa.                                      |
| This does not support calling C++.                                                               |
| When cgo is set, :param:`srcs` may contain C or assembly files; these files are compiled with    |
| the normal c compiler and included in the package.                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cdeps`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of other libraries that the c code depends on.                                          |
| This can be anything that would be allowed in `cc library deps`_                                 |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`copts`             | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C compilation command.                                               |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`clinkopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C link command.                                                      |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+

go_test
~~~~~~~

This builds a set of tests that can be run with ``bazel test``.

To run all tests in the workspace, and print output on failure (the
equivalent of ``go test ./...`` from ``go_prefix`` in a ``GOPATH`` tree), run

::

  bazel test --test_output=errors //...

You can run specific tests by passing the `--test_filter=pattern <test_filter_>`_ argument to Bazel.
You can pass arguments to tests by passing `--test_arg=arg <test_arg_>`_ arguments to Bazel.

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
|                                                                                                  |
| To interoperated cleanly with gazelle_ right now this should be :value:`go_default_test` for     |
| internal tests and :value:`go_default_xtest` for external tests.                                 |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this test. If unspecified, the test will have an implicit                     |
| dependency on ``//:go_prefix``, and the import path will be derived from the prefix              |
| and the test's label.                                                                            |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of Go source files that are compiled to create the test.                                |
| Only :value:`.go` files are permitted, unless the cgo attribute is set, in which case the        |
| following file types are permitted: :value:`.go, .c, .s, .S .h`.                                 |
| The files may contain Go-style `build constraints`_.                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this test imports directly.                                                 |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`embed`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this test embeds directly.                                                  |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
| These can provide both :param:`srcs` and :param:`deps` to this test.                             |
| See Embedding_ for more information about how and when to use this.                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_goopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go compilation command when using the gc compiler.                   |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_linkopts`       | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go link command when using the gc compiler.                          |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`x_defs`            | :type:`string_dict`         | :value:`{}`                           |
+----------------------------+-----------------------------+---------------------------------------+
| Map of defines to add to the go link command.                                                    |
| See `Defines and stamping`_ for examples of how to use these.                                    |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cgo`               | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True`, the binary uses cgo_.                                                          |
| The cgo tool permits Go code to call C code and vice-versa.                                      |
| This does not support calling C++.                                                               |
| When cgo is set, :param:`srcs` may contain C or assembly files; these files are compiled with    |
| the normal c compiler and included in the package.                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cdeps`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of other libraries that the c code depends on.                                          |
| This can be anything that would be allowed in `cc library deps`_                                 |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`copts`             | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C compilation command.                                               |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`clinkopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C link command.                                                      |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`rundir`            | :type:`string`              | The package path                      |
+----------------------------+-----------------------------+---------------------------------------+
| A directory to cd to before the test is run.                                                     |
| This should be a path relative to the execution dir of the test.                                 |
|                                                                                                  |
| The default behaviour is to change to the workspace relative path, this replicates the normal    |
| behaviour of ``go test`` so it is easy to write compatible tests.                                |
|                                                                                                  |
| Setting it to :value:`.` makes the test behave the normal way for a bazel test.                  |
+----------------------------+-----------------------------+---------------------------------------+

To write an internal test, reference the library being tested with the :param:`embed`
instead of :param:`deps`. This will compile the test sources into the same package as the library
sources.

Internal test example
^^^^^^^^^^^^^^^^^^^^^

This builds a test that can use the internal interface of the package being tested.

In the normal go toolchain this would be the kind of tests formed by adding writing
``<file>_test.go`` files in the same package.

It references the library being tested with :param:`embed`.


.. code:: bzl

  go_library(
      name = "go_default_library",
      srcs = ["lib.go"],
  )

  go_test(
      name = "go_default_test",
      srcs = ["lib_test.go"],
      embed = [":go_default_library"],
  )

External test example
^^^^^^^^^^^^^^^^^^^^^

This builds a test that can only use the public interface(s) of the packages being tested.

In the normal go toolchain this would be the kind of tests formed by adding an ``<name>_test``
package.

It references the library(s) being tested with :param:`deps`.

.. code:: bzl

  go_library(
      name = "go_default_library",
      srcs = ["lib.go"],
  )

  go_test(
      name = "go_default_xtest",
      srcs = ["lib_x_test.go"],
      deps = [":go_default_library"],
  )

go_source
~~~~~~~~~

This declares a set of source files and related dependencies that can be embedded into one of the
other rules.
This is used as a way of easily declaring a common set of sources re-used in multiple rules.

Providers
^^^^^^^^^

* GoLibrary_
* GoSource_

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of Go source files that are compiled to create the package.                             |
| The following file types are permitted: :value:`.go, .c, .s, .S .h`.                             |
| The files may contain Go-style `build constraints`_.                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this source list imports directly.                                          |
| These may be go_library rules or compatible rules with the GoLibrary_ provider.                  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`embed`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of sources to directly embed in this list.                                                  |
| These may be go_library rules or compatible rules with the GoSource_ provider.                   |
| These can provide both :param:`srcs` and :param:`deps` to this library.                          |
| See Embedding_ for more information about how and when to use this.                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gc_goopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the Go compilation command when using the gc compiler.                   |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
+----------------------------+-----------------------------+---------------------------------------+

