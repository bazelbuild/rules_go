Core Go rules
=============

.. _"Make variable": https://docs.bazel.build/versions/master/be/make-variables.html
.. _Bourne shell tokenization: https://docs.bazel.build/versions/master/be/common-definitions.html#sh-tokenization
.. _Gazelle: https://github.com/bazelbuild/bazel-gazelle
.. _GoArchive: providers.rst#GoArchive
.. _GoLibrary: providers.rst#GoLibrary
.. _GoPath: providers.rst#GoPath
.. _GoSource: providers.rst#GoSource
.. _build constraints: https://golang.org/pkg/go/build/#hdr-Build_Constraints
.. _cc library deps: https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library.deps
.. _cgo: http://golang.org/cmd/cgo/
.. _config_setting: https://docs.bazel.build/versions/master/be/general.html#config_setting
.. _data dependencies: https://docs.bazel.build/versions/master/build-ref.html#data
.. _goarch: modes.rst#goarch
.. _goos: modes.rst#goos
.. _mode attributes: modes.rst#mode-attributes
.. _nogo: nogo.rst#nogo
.. _pure: modes.rst#pure
.. _select: https://docs.bazel.build/versions/master/be/functions.html#select
.. _shard_count: https://docs.bazel.build/versions/master/be/common-definitions.html#test.shard_count
.. _static: modes.rst#static
.. _test_arg: https://docs.bazel.build/versions/master/user-manual.html#flag--test_arg
.. _test_filter: https://docs.bazel.build/versions/master/user-manual.html#flag--test_filter
.. _write a CROSSTOOL file: https://github.com/bazelbuild/bazel/wiki/Yet-Another-CROSSTOOL-Writing-Tutorial

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

These are the core go rules, required for basic operation.
The intent is that these rules are sufficient to match the capabilities of the normal go tools.

.. contents:: :depth: 2

-----

Introduction
------------

Three core rules may be used to build most projects: `go_library`_, `go_binary`_,
and `go_test`_.

`go_library`_ builds a single package. It has a list of source files
(specified with ``srcs``) and may depend on other packages (with ``deps``).
Each `go_library`_ has an ``importpath``, which is the name used to import it
in Go source files.

`go_binary`_ also builds a single ``main`` package and links it into an
executable. It may embed the content of a `go_library`_ using the ``embed``
attribute. Embedded sources are compiled together in the same package.
Binaries can be built for alternative platforms and configurations by setting
``goos``, ``goarch``, and other attributes.

`go_test`_ builds a test executable. Like tests produced by ``go test``, this
consists of three packages: an internal test package compiled together with
the library being tested (specified with ``embed``), an external test package
compiled separately, and a generated test main package.

Defines and stamping
~~~~~~~~~~~~~~~~~~~~

In order to provide build time information to go code without data files, we
support the concept of stamping.

Stamping asks the linker to substitute the value of a global variable with a
string determined at link time. Stamping only happens when linking a binary, not
when compiling a package. This means that changing a value results only in
re-linking, not re-compilation and thus does not cause cascading changes.

Link values are set in the :param:`x_defs` attribute of any Go rule. This is a
map of string to string, where keys are the names of variables to substitute,
and values are the string to use. Keys may be names of variables in the package
being compiled, or they may be fully qualified names of variables in another
package.

These mappings are collected up across the entire transitive dependencies of a
binary. This means you can set a value using :param:`x_defs` in a
``go_library``, and any binary that links that library will be stamped with that
value. You can also override stamp values from libraries using :param:`x_defs`
on the ``go_binary`` rule if needed. The ``--[no]stamp`` option controls whether 
stamping of workspace variables is enabled.

Example
^^^^^^^

Suppose we have a small library that contains the current version.

.. code:: go

    package version

    var Version = "redacted"

We can set the version in the ``go_library`` rule for this library.

.. code:: bzl

    go_library(
        name = "go_default_library",
        srcs = ["version.go"],
        importpath = "example.com/repo/version",
        x_defs = {"Version": "0.9"},
    )

Binaries that depend on this library may also set this value.

.. code:: bzl

    go_binary(
        name = "cmd",
        srcs = ["main.go"],
        deps = ["//version:go_default_library"],
        x_defs = {"example.com/repo/version.Version": "0.9"},
    )

Stamping with the workspace status script
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You can use values produced by the workspace status command in your link stamp.
To use this functionality, write a script that prints key-value pairs, separated
by spaces, one per line. For example:

.. code:: bash

    #!/usr/bin/env bash

    echo STABLE_GIT_COMMIT $(git rev-parse HEAD)

**NOTE:** keys that start with ``STABLE_`` will trigger a re-link when they change.
Other keys will NOT trigger a re-link.

You can reference these in :param:`x_defs` using curly braces.

.. code:: bzl

    go_binary(
        name = "cmd",
        srcs = ["main.go"],
        deps = ["//version:go_default_library"],
        x_defs = {"example.com/repo/version.Version": "{STABLE_GIT_COMMIT}"},
    )

You can build using the status script using the ``--workspace_status_command``
argument on the command line:

.. code:: bash

    $ bazel build --stamp --workspace_status_command=./status.sh //:cmd

Embedding
~~~~~~~~~

The sources, dependencies, and data of a ``go_library`` may be *embedded*
within another ``go_library``, ``go_binary``, or ``go_test`` using the ``embed``
attribute. The embedding package will be compiled into a single archive
file. The embedded package may still be compiled as a separate target.

A minimal example of embedding is below. In this example, the command ``bazel
build :foo_and_bar`` will compile ``foo.go`` and ``bar.go`` into a single
archive. ``bazel build :bar`` will compile only ``bar.go``. Both libraries must
have the same ``importpath``.

.. code:: bzl

    go_library(
        name = "foo_and_bar",
        srcs = ["foo.go"],
        embed = [":bar"],
        importpath = "example.com/foo",
    )

    go_library(
        name = "bar",
        srcs = ["bar.go"],
        importpath = "example.com/foo",
    )

Embedding is most frequently used for tests and binaries. Go supports two
different kinds of tests. *Internal tests* (e.g., ``package foo``) are compiled
into the same archive as the library under test and can reference unexported
definitions in that library. *External tests* (e.g., ``package foo_test``) are
compiled into separate archives and may depend on exported definitions from the
internal test archive.

In order to compile the internal test archive, we *embed* the ``go_library``
under test into a ``go_test`` that contains the test sources. The ``go_test``
rule can automatically distinguish internal and external test sources, so they
can be listed together in ``srcs``. The ``go_library`` under test does not
contain test sources. Other ``go_binary`` and ``go_library`` targets can depend
on it or embed it.

.. code:: bzl

    go_library(
        name = "go_default_library",
        srcs = ["foo.go"],
        importpath = "example.com/foo",
    )

    go_binary(
        name = "foo",
        embed = [":go_default_library"],
    )

    go_test(
        name = "go_default_test",
        srcs = [
            "foo_external_test.go",
            "foo_internal_test.go",
        ],
        embed = [":go_default_library"],
    )

Embedding may also be used to add extra sources sources to a
``go_proto_library``.

.. code:: bzl

    proto_library(
        name = "foo_proto",
        srcs = ["foo.proto"],
    )

    go_proto_library(
        name = "foo_go_proto",
        importpath = "example.com/foo",
        proto = ":foo_proto",
    )

    go_library(
        name = "go_default_library",
        srcs = ["extra.go"],
        embed = [":foo_go_proto"],
        importpath = "example.com/foo",
    )

Rules
-----

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
| To interoperate cleanly with Gazelle_ right now this should be :value:`go_default_library`.      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| The source import path of this library. Other libraries can import this                          |
| library using this path. This must either be specified in ``go_library`` or                      |
| inherited from one of the libraries in ``embed``.                                                |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importmap`         | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The actual import path of this library. This is mostly only visible to the                       |
| compiler and linker, but it may also be seen in stack traces. This may be set                    |
| to prevent a binary from linking multiple packages with the same import path                     |
| e.g., from different vendor directories.                                                         |
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
| List of Go libraries whose sources should be compiled together with this                         |
| library's sources. Labels listed here must name ``go_library``,                                  |
| ``go_proto_library``, or other compatible targets with the GoLibrary_ and                        |
| GoSource_ providers. Embedded libraries must have the same ``importpath`` as                     |
| the embedding library. At most one embedded library may have ``cgo = True``,                     |
| and the embedding library may not also have ``cgo = True``. See Embedding_                       |
| for more information.                                                                            |
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
| When cgo is set, :param:`srcs` may contain C, C++, Objective-C, Objective-C++,                   |
| and assembly files. These files will be compiled with the compiler from                          |
| the configured C/C++ toolchain. The compiled objects are included in                             |
| the package.                                                                                     |
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
| :param:`cxxopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C++ compilation command.                                             |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cppopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C/C++ preprocessor command.                                          |
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

go_tool_library
~~~~~~~~~~~~~~~

This builds a Go library from a set of source files that are all part of
the same package.

This rule is a limited variant of ``go_library`` which may be used to
bootstrap tools used by rules_go. This avoids a circular dependency.
If you are building analyzers to be linked into a `nogo`_ binary, you'll
need to use ``go_tool_library`` since ``go_library`` depends on `nogo`_
implicitly.

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
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of Go source files that are compiled to create the package.                             |
| Only :value:`.go` files are permitted. Cgo, assembly, and build constraints                      |
| are not supported.                                                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries this library imports directly.                                              |
| These must be ``go_tool_library`` targets to avoid circular dependencies.                        |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`embed`             | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries whose sources should be compiled together with this                         |
| library's sources. Labels listed here must name ``go_tool_library`` targets.                     |
| Embedded libraries must have the same ``importpath`` as the embedding library.                   |
| See Embedding_ for more information.                                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+

Example
^^^^^^^

.. code:: bzl

    go_tool_library(
        name = "importunsafe",
        srcs = ["importunsafe.go"],
        importpath = "importunsafe",
        deps = ["@org_golang_x_tools//go/analysis:go_tool_library"],
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
| List of Go libraries whose sources should be compiled together with this                         |
| binary's sources. Labels listed here must name ``go_library``,                                   |
| ``go_proto_library``, or other compatible targets with the GoLibrary_ and                        |
| GoSource_ providers. Embedded libraries must all have the same ``importpath``,                   |
| which must match the ``importpath`` for this ``go_binary`` if one is                             |
| specified. At most one embedded library may have ``cgo = True``, and the                         |
| embedding binary may not also have ``cgo = True``. See Embedding_ for                            |
| more information.                                                                                |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this binary. Binaries can't actually be imported, but this                    |
| may be used by `go_path`_ and other tools to report the location of source                       |
| files. This may be inferred from embedded libraries.                                             |
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
| :param:`race`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to instrument                        |
| code for data race detection. It may be :value:`on`, :value:`off`, or                            |
| :value:`auto`. In most cases, it's better to enable race detection globally                      |
| with ``--@io_bazel_rules_go//go/config:race`` on the command line.                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`msan`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to instrument                        |
| code for memory sanitization. It may be :value:`on`, :value:`off`, or                            |
| :value:`auto`. In most cases, it's better to enable memory sanitization                          |
| globally with ``--@io_bazel_rules_go//go/config:msan`` on the command line.                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gotags`            | :type:`string_list`         : :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which build tags are                         |
| enabled when evaluating build constraints. Useful for conditional compilation.                   |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goos`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goos_ to compile and link for.         |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrides the default as set by the current     |
| target platform and allows for single builds to make binaries for multiple architectures.        |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
|                                                                                                  |
| This attribute has several limitations and should only be used in situations where the           |
| ``--platforms`` flag does not work. See `Cross compilation`_ and `Note on goos and goarch        |
| attributes`_ for more information.                                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goarch`            | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goarch_ to compile and link for.       |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrides the default as set by the current     |
| target platform and allows for single builds to make binaries for multiple architectures.        |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
|                                                                                                  |
| This attribute has several limitations and should only be used in situations where the           |
| ``--platforms`` flag does not work. See `Cross compilation`_ and `Note on goos and goarch        |
| attributes`_ for more information.                                                               |
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
| When cgo is set, :param:`srcs` may contain C, C++, Objective-C, Objective-C++,                   |
| and assembly files. These files will be compiled with the compiler from                          |
| the configured C/C++ toolchain. The compiled objects are included in                             |
| the package.                                                                                     |
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
| :param:`cxxopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C++ compilation command.                                             |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cppopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C/C++ preprocessor command.                                          |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`clinkopts`         | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C link command.                                                      |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`linkmode`          | :type:`string`              | :value:`"normal"`                     |
+----------------------------+-----------------------------+---------------------------------------+
| Determines how the binary should be built and linked. This accepts some of                       |
| the same values as ``go build -buildmode`` and works the same way.                               |
|                                                                                                  |
| :value:`normal`                                                                                  |
|     Builds a normal executable with position-dependent code.                                     |
| :value:`pie`                                                                                     |
|     Builds a position-independent executable.                                                    |
| :value:`plugin`                                                                                  |
|     Builds a shared library that can be loaded as a Go plugin. Only supported                    |
|     on platforms that support plugins.                                                           |
| :value:`c-shared`                                                                                |
|     Builds a shared library that can be linked into a C program.                                 |
| :value:`c-archive`                                                                               |
|     Builds an archive that can be linked into a C program.                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`out`               | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| Sets the output filename for the generated executable. When set, ``go_binary``                   |
| will write this file without mode-specific directory prefixes, without                           |
| linkmode-specific prefixes like "lib", and without platform-specific suffixes                    |
| like ".exe". Note that without a mode-specific directory prefix, the                             |
| output file (but not its dependencies) will be invalidated in Bazel's cache                      |
| when changing configurations.                                                                    |
+----------------------------+-----------------------------+---------------------------------------+

go_test
~~~~~~~

This builds a set of tests that can be run with ``bazel test``.

To run all tests in the workspace, and print output on failure (the
equivalent of ``go test ./...``), run

::

  bazel test --test_output=errors //...

To run a Go benchmark test, run

::

  bazel run //path/to:test -- -test.bench=.

You can run specific tests by passing the `--test_filter=pattern <test_filter_>`_ argument to Bazel.
You can pass arguments to tests by passing `--test_arg=arg <test_arg_>`_ arguments to Bazel.

To write structured testlog information to Bazel's ``XML_OUTPUT_FILE``, tests ran with ``bazel test`` execute using a wrapper that invokes the testbinary with ``-test.v``. This functionality can be disabled by setting ``GO_TEST_WRAP=0`` in the test environment.

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
|                                                                                                  |
| To interoperate cleanly with Gazelle_ right now this should be :value:`go_default_test` for      |
| internal tests and :value:`go_default_xtest` for external tests.                                 |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this test. Tests can't actually be imported, but this                         |
| may be used by `go_path`_ and other tools to report the location of source                       |
| files. This may be inferred from embedded libraries.                                             |
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
| List of Go libraries whose sources should be compiled together with this                         |
| test's sources. Labels listed here must name ``go_library``,                                     |
| ``go_proto_library``, or other compatible targets with the GoLibrary_ and                        |
| GoSource_ providers. Embedded libraries must have the same ``importpath`` as                     |
| the embedding test, if one is specified. At most one embedded library may                        |
| have ``cgo = True``, and the embedding test may not also have ``cgo = True``.                    |
| See Embedding_ for more information.                                                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| The list of files needed by this rule at runtime. Targets named in the data attribute will       |
| appear in the *.runfiles area of this rule, if it has one. This may include data files needed    |
| by the binary, or other programs needed by it. See `data dependencies`_ for more information     |
| about how to depend on and use data files.                                                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The import path of this test. Tests can't actually be imported, but this                         |
| may be used by `go_path`_ and other tools to report the location of source                       |
| files. This may be inferred from embedded libraries.                                             |
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
| :param:`race`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to instrument                        |
| code for data race detection. It may be :value:`on`, :value:`off`, or                            |
| :value:`auto`. In most cases, it's better to enable race detection globally                      |
| with ``--@io_bazel_rules_go//go/config:race`` on the command line.                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`msan`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls whether to instrument                        |
| code for memory sanitization. It may be :value:`on`, :value:`off`, or                            |
| :value:`auto`. In most cases, it's better to enable memory sanitization                          |
| globally with ``--@io_bazel_rules_go//go/config:msan`` on the command line.                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`gotags`            | :type:`string_list`         : :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which build tags are                         |
| enabled when evaluating build constraints. Useful for conditional compilation.                   |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goos`              | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goos_ to compile and link for.         |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrides the default as set by the current     |
| target platform and allows for single builds to make binaries for multiple architectures.        |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
|                                                                                                  |
| This attribute has several limitations and should only be used in situations where the           |
| ``--platforms`` flag does not work. See `Cross compilation`_ and `Note on goos and goarch        |
| attributes`_ for more information.                                                               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`goarch`            | :type:`string`              | :value:`auto`                         |
+----------------------------+-----------------------------+---------------------------------------+
| This is one of the `mode attributes`_ that controls which goarch_ to compile and link for.       |
|                                                                                                  |
| If set to anything other than :value:`auto` this overrides the default as set by the current     |
| target platform and allows for single builds to make binaries for multiple architectures.        |
|                                                                                                  |
| Because this has no control over the cc toolchain, it does not work for cgo, so if this          |
| attribute is set then :param:`pure` must be set to :value:`on`.                                  |
|                                                                                                  |
| This attribute has several limitations and should only be used in situations where the           |
| ``--platforms`` flag does not work. See `Cross compilation`_ and `Note on goos and goarch        |
| attributes`_ for more information.                                                               |
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
| When cgo is set, :param:`srcs` may contain C, C++, Objective-C, Objective-C++,                   |
| and assembly files. These files will be compiled with the compiler from                          |
| the configured C/C++ toolchain. The compiled objects are included in                             |
| the package.                                                                                     |
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
| :param:`cxxopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C++ compilation command.                                             |
| Subject to `"Make variable"`_ substitution and `Bourne shell tokenization`_.                     |
| Only valid if :param:`cgo` = :value:`True`.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`cppopts`           | :type:`string_list`         | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| List of flags to add to the C/C++ preprocessor command.                                          |
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
| :param:`shard_count`       | :type:`integer`             | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| Non-negative integer less than or equal to 50, optional.                                         |
|                                                                                                  |
| Specifies the number of parallel shards to run the test. Test methods will be split across the   |
| shards in a round-robin fashion.                                                                 |
|                                                                                                  |
| For more details on this attribute, consult the official Bazel documentation for shard_count_.   |
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

go_path
~~~~~~~

``go_path`` builds a directory structure that can be used with tools that
understand the ``GOPATH`` directory layout. This directory structure can be
built by zipping, copying, or linking files.

``go_path`` can depend on one or more Go targets (i.e., `go_library`_,
`go_binary`_, or `go_test`_). It will include packages from those targets, as
well as their transitive dependencies. Packages will be in subdirectories named
after their ``importpath`` or ``importmap`` attributes under a ``src/``
directory.

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| A list of targets that build Go packages. A directory will be generated from                     |
| files in these targets and their transitive dependencies. All targets must                       |
| provide GoArchive_ (`go_library`_, `go_binary`_, `go_test`_, and similar                         |
| rules have this).                                                                                |
|                                                                                                  |
| Only targets with explicit ``importpath`` attributes will be included in the                     |
| generated directory. Synthetic packages (like the main package produced by                       |
| `go_test`_) and packages with inferred import paths will not be                                  |
| included. The values of ``importmap`` attributes may influence the placement                     |
| of packages within the generated directory (for example, in vendor                               |
| directories).                                                                                    |
|                                                                                                  |
| The generated directory will contain original source files, including .go,                       |
| .s, .h, and .c files compiled by cgo. It will not contain files generated by                     |
| tools like cover and cgo, but it will contain generated files passed in                          |
| ``srcs`` attributes like .pb.go files. The generated directory will also                         |
| contain runfiles found in ``data`` attributes.                                                   |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`data`              | :type:`label_list`          | :value:`[]`                           |
+----------------------------+-----------------------------+---------------------------------------+
| A list of targets producing data files that will be stored next to the                           |
| ``src/`` directory. Useful for including things like licenses and readmes.                       |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`mode`              | :type:`string`              | :value:`"copy"`                       |
+----------------------------+-----------------------------+---------------------------------------+
| Determines how the generated directory is provided. May be one of:                               |
|                                                                                                  |
| * ``"archive"``: The generated directory is packaged as a single .zip file.                      |
| * ``"copy"``: The generated directory is a single tree artifact. Source files                    |
|   are copied into the tree.                                                                      |
| * ``"link"``: Source files are symlinked into the tree. All of the symlink                       |
|   files are provided as separate output files.                                                   |
|                                                                                                  |
| **NOTE:** In ``"copy"`` mode, when a ``GoPath`` is consumed as a set of input                    |
| files or run files, Bazel may provide symbolic links instead of regular files.                   |
| Any program that consumes these files should dereference links, e.g., if you                     |
| run ``tar``, use the ``--dereference`` flag.                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`include_data`      | :type:`bool`                | :value:`True`                         |
+----------------------------+-----------------------------+---------------------------------------+
| When true, data files referenced by libraries, binaries, and tests will be                       |
| included in the output directory. Files listed in the :param:`data` attribute                    |
| for this rule will be included regardless of this attribute.                                     |
+----------------------------+-----------------------------+---------------------------------------+

Cross compilation
-----------------

rules_go can cross-compile Go projects to any platform the Go toolchain
supports. The simplest way to do this is by setting the ``--platforms`` flag on
the command line.

.. code::

    $ bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 //my/project

You can replace ``linux_amd64`` in the example above with any valid
GOOS / GOARCH pair. To list all platforms, run this command:

.. code::

    $ bazel query 'kind(platform, @io_bazel_rules_go//go/toolchain:all)'

By default, cross-compilation will cause Go targets to be built in "pure mode",
which disables cgo; cgo files will not be compiled, and C/C++ dependencies will
not be compiled or linked.

Cross-compiling cgo code is possible, but not fully supported. You will need to
`write a CROSSTOOL file`_ that describes your C/C++ toolchain. You'll need to
ensure it works by building ``cc_binary`` and ``cc_library`` targets with the
``--cpu`` command line flag set. Then, to build a mixed Go / C / C++ project,
add ``pure = "off"`` to your ``go_binary`` target and run Bazel with ``--cpu``
and ``--platforms``.

Platform-specific dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When cross-compiling, you may have some platform-specific sources and
dependencies. Source files from all platforms can be mixed freely in a single
``srcs`` list. Source files are filtered using `build constraints`_ (filename
suffixes and ``+build`` tags) before being passed to the compiler.

Platform-specific dependencies are another story. For example, if you are
building a binary for Linux, and it has dependency that should only be built
when targeting Windows, you will need to filter it out using Bazel `select`_
expressions:

.. code:: bzl

    go_binary(
        name = "cmd",
        srcs = [
            "foo_linux.go",
            "foo_windows.go",
        ],
        deps = [
            # platform agnostic dependencies
            "//bar:go_default_library",
        ] + select({
            # OS-specific dependencies
            "@io_bazel_rules_go//go/platform:linux": [
                "//baz_linux:go_default_library",
            ],
            "@io_bazel_rules_go//go/platform:windows": [
                "//quux_windows:go_default_library",
            ],
            "//conditions:default": [],
        }),
    )

``select`` accepts a dictionary argument. The keys are labels that reference
`config_setting`_ rules. The values are lists of labels. Exactly one of these
lists will be selected, depending on the target configuration. rules_go has
pre-declared ``config_setting`` rules for each OS, architecture, and
OS-architecture pair. For a full list, run this command:

.. code::

    $ bazel query 'kind(config_setting, @io_bazel_rules_go//go/platform:all)'

`Gazelle`_ will generate dependencies in this format automatically.
