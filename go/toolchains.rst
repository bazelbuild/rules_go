Go toolchains
=============

.. _Args: https://docs.bazel.build/versions/master/skylark/lib/Args.html
.. _Bazel toolchains: https://docs.bazel.build/versions/master/toolchains.html
.. _Go website: https://golang.org/
.. _GoArchive: providers.rst#goarchive
.. _GoLibrary: providers.rst#golibrary
.. _GoSDK: providers.rst#gosdk
.. _GoSource: providers.rst#gosource
.. _binary distribution: https://golang.org/dl/
.. _compilation modes: modes.rst#compilation-modes
.. _control the version: `Forcing the Go version`_
.. _core: core.bzl
.. _forked version of Go: `Registering a custom SDK`_
.. _go assembly: https://golang.org/doc/asm
.. _go sdk rules: `The SDK`_
.. _go/platform/list.bzl: platform/list.bzl
.. _installed SDK: `Using the installed Go sdk`_
.. _nogo: nogo.rst#nogo
.. _register: Registration_
.. _register_toolchains: https://docs.bazel.build/versions/master/skylark/lib/globals.html#register_toolchains

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

The Go toolchain is at the heart of the Go rules, and is the mechanism used to
customize the behavior of the core_ Go rules.

.. contents:: :depth: 2

-----

Overview
--------

The Go toolchain consists of three main layers: `the SDK`_, `the toolchain`_,
and `the context`_.

The SDK
~~~~~~~

The Go SDK (more commonly known as the Go distribution) is a directory tree
containing sources for the Go toolchain and standard library and pre-compiled
binaries for the same. You can download this from by visiting the `Go website`_
and downloading a `binary distribution`_.

There are several Bazel rules for obtaining and configuring a Go SDK:

* `go_download_sdk`_: downloads a toolchain for a specific version of Go for a
  specific operating system and architecture.
* `go_host_sdk`_: uses the toolchain installed on the system where Bazel is
  run. The toolchain's location is specified with the ``GOROOT`` or by running
  ``go env GOROOT``.
* `go_local_sdk`_: like `go_host_sdk`_, but uses the toolchain in a specific
  directory on the host system.
* `go_wrap_sdk`_: configures a toolchain downloaded with another Bazel
  repository rule.

By default, if none of the above rules are used, the `go_register_toolchains`_
function creates a repository named ``@go_sdk`` using `go_download_sdk`_, using
a recent version of Go for the host operating system and architecture.

SDKs are specific to a host platform (e.g., ``linux_amd64``) and a version of
Go. They may target all platforms that Go supports. The Go SDK is naturally
cross compiling.

The toolchain
~~~~~~~~~~~~~

The workspace rules above declare `Bazel toolchains`_ with `go_toolchain`_
implementations for each target platform that Go supports. Wrappers around
the rules register these toolchains automatically. Bazel will select a
registered toolchain automatically based on the execution and target platforms,
specified with ``--host_platform`` and ``--platforms``, respectively.

The toolchain itself should be considered opaque. You should only access
its contents through `the context`_.

The context
~~~~~~~~~~~

The context is the type you need if you are writing custom rules that need
to be compatible with rules_go. It provides information about the SDK, the
toolchain, and the standard library. It also provides a convenient way to
declare mode-specific files, and to create actions for compiling, linking,
and more.

Customizing
-----------

Normal usage
~~~~~~~~~~~~

This is an example of normal usage for the other examples to be compared
against. This will download and use a specific version of Go for the host
platform.

.. code:: bzl

    # WORKSPACE

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains(version = "1.15.5")


Using the installed Go SDK
~~~~~~~~~~~~~~~~~~~~~~~~~~

You can use the Go SDK that's installed on the system where Bazel is running.
This may result in faster builds, since there's no need to download an SDK,
but builds won't be reproducible across systems with different SDKs installed.

.. code:: bzl

    # WORKSPACE

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains(version = "host")


Registering a custom SDK
~~~~~~~~~~~~~~~~~~~~~~~~

If you download the SDK through another repository rule, you can configure
it with ``go_wrap_sdk``. It must still be named ``go_sdk``, but this is a
temporary limitation that will be removed in the future.

.. code:: bzl

    # WORKSPACE

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains", "go_wrap_sdk")

    unknown_download_sdk(
        name = "go",
        ...,
    )

    go_wrap_sdk(
        name = "go_sdk",
        root_file = "@go//:README.md",
    )

    go_rules_dependencies()

    go_register_toolchains()


Writing new Go rules
~~~~~~~~~~~~~~~~~~~~

If you are writing a new Bazel rule that uses the Go toolchain, you need to
do several things to ensure you have full access to the toolchain and common
dependencies.

* Declare a dependency on a toolchain of type
  ``@io_bazel_rules_go//go:toolchain``. Bazel will select an appropriate,
  registered toolchain automatically.
* Declare an implicit attribute named ``_go_context_data`` that defaults to
  ``@io_bazel_rules_go//:go_context_data``. This target gathers configuration
  information and several common dependencies.
* Use the ``go_context`` function to gain access to `the context`_. This is
  your main interface to the Go toolchain.

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_context")

    def _my_rule_impl(ctx):
        go = go_context(ctx)
        ...

    my_rule = rule(
        implementation = _my_rule_impl,
        attrs = {
            ...
            "_go_context_data": attr.label(
                default = "@io_bazel_rules_go//:go_context_data",
            ),
        },
        toolchains = ["@io_bazel_rules_go//go:toolchain"],
    )


Rules and functions
-------------------

go_register_toolchains
~~~~~~~~~~~~~~~~~~~~~~

Installs the Go toolchains. If :param:`version` is specified, it sets the
SDK version to use (for example, :value:`"1.15.5"`).

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`version`               | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Specifies the version of Go to download if one has not been declared.                            |
|                                                                                                  |
| If a toolchain was already declared with `go_download_sdk`_ or a similar rule,                   |
| this parameter may not be set.                                                                   |
|                                                                                                  |
| Normally this is set to a Go version like :value:`"1.15.5"`. It may also be                      |
| set to :value:`"host"`, which will cause rules_go to use the Go toolchain                        |
| installed on the host system (found using ``GOROOT`` or ``PATH``).                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`nogo`                  | :type:`label`               | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| The ``nogo`` attribute refers to a nogo_ rule that builds a binary                               |
| used for static analysis. The ``nogo`` binary will be used alongside the                         |
| Go compiler when building packages.                                                              |
+--------------------------------+-----------------------------+-----------------------------------+

go_download_sdk
~~~~~~~~~~~~~~~

This downloads a Go SDK for use in toolchains.

+--------------------------------+-----------------------------+---------------------------------------------+
| **Name**                       | **Type**                    | **Default value**                           |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                                 |
+--------------------------------+-----------------------------+---------------------------------------------+
| A unique name for this SDK. This should almost always be :value:`go_sdk` if                                |
| you want the SDK to be used by toolchains.                                                                 |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`goos`                  | :type:`string`              | :value:`None`                               |
+--------------------------------+-----------------------------+---------------------------------------------+
| The operating system the binaries in the SDK are intended to run on.                                       |
| By default, this is detected automatically, but if you're building on                                      |
| an unusual platform, or if you're using remote execution and the execution                                 |
| platform is different than the host, you may need to specify this explictly.                               |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`goarch`                | :type:`string`              | :value:`None`                               |
+--------------------------------+-----------------------------+---------------------------------------------+
| The architecture the binaries in the SDK are intended to run on.                                           |
| By default, this is detected automatically, but if you're building on                                      |
| an unusual platform, or if you're using remote execution and the execution                                 |
| platform is different than the host, you may need to specify this explictly.                               |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`version`               | :type:`string`              | :value:`latest Go version`                  |
+--------------------------------+-----------------------------+---------------------------------------------+
| The version of Go to download, for example ``1.12.5``. If unspecified,                                     |
| ``go_download_sdk`` will list available versions of Go from golang.org, then                               |
| pick the highest version. If ``version`` is specified but ``sdks`` is                                      |
| unspecified, ``go_download_sdk`` will list available versions on golang.org                                |
| to determine the correct file name and SHA-256 sum.                                                        |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`urls`                  | :type:`string_list`         | :value:`[https://dl.google.com/go/{}]`      |
+--------------------------------+-----------------------------+---------------------------------------------+
| A list of mirror urls to the binary distribution of a Go SDK. These must contain the `{}`                  |
| used to substitute the sdk filename being fetched (using `.format`.                                        |
| It defaults to the official repository :value:`"https://dl.google.com/go/{}"`.                             |
|                                                                                                            |
| This attribute is seldom used. It is only needed for downloading Go from                                   |
| an alternative location (for example, an internal mirror).                                                 |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`strip_prefix`          | :type:`string`              | :value:`"go"`                               |
+--------------------------------+-----------------------------+---------------------------------------------+
| A directory prefix to strip from the extracted files.                                                      |
| Used with ``urls``.                                                                                        |
+--------------------------------+-----------------------------+---------------------------------------------+
| :param:`sdks`                  | :type:`string_list_dict`    | :value:`see description`                    |
+--------------------------------+-----------------------------+---------------------------------------------+
| This consists of a set of mappings from the host platform tuple to a list of filename and                  |
| sha256 for that file. The filename is combined the :param:`urls` to produce the final download             |
| urls to use.                                                                                               |
|                                                                                                            |
| This option is seldom used. It is only needed for downloading a modified                                   |
| Go distribution (with a different SHA-256 sum) or a version of Go                                          |
| not supported by rules_go (for example, a beta or release candidate).                                      |
+--------------------------------+-----------------------------+---------------------------------------------+

**Example**:

.. code:: bzl

    load(
        "@io_bazel_rules_go//go:deps.bzl",
        "go_download_sdk",
        "go_register_toolchains",
        "go_rules_dependencies",
    )

    go_download_sdk(
        name = "go_sdk",
        goos = "linux",
        goarch = "amd64",
        version = "1.12.5",
    )

    go_rules_dependencies()

    go_register_toolchains()

go_host_sdk
~~~~~~~~~~~

This detects and configures the host Go SDK for use in toolchains.

If the ``GOROOT`` environment variable is set, the SDK in that directory is
used. Otherwise, ``go env GOROOT`` is used.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this SDK. This should almost always be :value:`go_sdk` if you want the SDK     |
| to be used by toolchains.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+


go_local_sdk
~~~~~~~~~~~~

This prepares a local path to use as the Go SDK in toolchains.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this SDK. This should almost always be :value:`go_sdk` if you want the SDK     |
| to be used by toolchains.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`path`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The local path to a pre-installed Go SDK. The path must contain the go binary, the tools it      |
| invokes and the standard library sources.                                                        |
+--------------------------------+-----------------------------+-----------------------------------+


go_wrap_sdk
~~~~~~~~~~~

This configures an SDK that was downloaded or located with another repository
rule.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this SDK. This should almost always be :value:`go_sdk` if you want the SDK     |
| to be used by toolchains.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`root_file`             | :type:`label`               | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A Bazel label referencing a file in the root directory of the SDK. Used to                       |
| determine the GOROOT for the SDK.                                                                |
+--------------------------------+-----------------------------+-----------------------------------+

**Example:**

.. code:: bzl

    load(
        "@io_bazel_rules_go//go:deps.bzl",
        "go_register_toolchains",
        "go_rules_dependencies",
        "go_wrap_sdk",
    )

    go_wrap_sdk(
        name = "go_sdk",
        root_file = "@other_repo//go:README.md",
    )

    go_rules_dependencies()

    go_register_toolchains()

go_toolchain
~~~~~~~~~~~~

This declares a toolchain that may be used with toolchain type
:value:`"@io_bazel_rules_go//go:toolchain"`.

Normally, ``go_toolchain`` rules are declared and registered in repositories
configured with `go_download_sdk`_, `go_host_sdk`_, `go_local_sdk`_, or
`go_wrap_sdk`_. You usually won't need to declare these explicitly.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for the toolchain.                                                                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`goos`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The target operating system. Must be a standard ``GOOS`` value.                                  |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`goarch`                | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The target architecture. Must be a standard ``GOARCH`` value.                                    |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sdk`                   | :type:`label`               | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The SDK this toolchain is based on. The target must provide `GoSDK`_. This is                    |
| usually a `go_sdk`_ rule.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`link_flags`            | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Flags passed to the Go external linker.                                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`cgo_link_flags`        | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Flags passed to the external linker (if it is used).                                             |
+--------------------------------+-----------------------------+-----------------------------------+

go_context
~~~~~~~~~~

This collects the information needed to form and return a :type:`GoContext` from
a rule ctx.  It uses the attributes and the toolchains.  It can only be used in
the implementation of a rule that has the go toolchain attached and the go
context data as an attribute. To do this declare the rule using the go_rule
wrapper.

.. code:: bzl

  def _my_rule_impl(ctx):
      go = go_context(ctx)
      ...

  my_rule = go_rule(
      _my_rule_impl,
      attrs = {
          ...
      },
  )


+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`ctx`                 | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The Bazel ctx object for the current rule.                                                       |
+--------------------------------+-----------------------------+-----------------------------------+

The context object
~~~~~~~~~~~~~~~~~~

``GoContext`` is never returned by a rule, instead you build one using
``go_context(ctx)`` in the top of any custom starlark rule that wants to interact
with the go rules.  It provides all the information needed to create go actions,
and create or interact with the other go providers.

When you get a ``GoContext`` from a context it exposes a number of fields
and methods.

All methods take the ``GoContext`` as the only positional argument. All other
arguments must be passed as keyword arguments. This allows us to re-order and
deprecate individual parameters over time.

Fields
^^^^^^

+--------------------------------+-----------------------------------------------------------------+
| **Name**                       | **Type**                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`toolchain`             | :type:`ToolchainInfo`                                           |
+--------------------------------+-----------------------------------------------------------------+
| The underlying toolchain. This should be considered an opaque type subject to change.            |
+--------------------------------+-----------------------------------------------------------------+
| :param:`sdk`                   | :type:`GoSDK`                                                   |
+--------------------------------+-----------------------------------------------------------------+
| The SDK in use. This may be used to access sources, packages, and tools.                         |
+--------------------------------+-----------------------------------------------------------------+
| :param:`mode`                  | :type:`Mode`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| Controls the compilation setup affecting things like enabling profilers and sanitizers.          |
| See `compilation modes`_ for more information about the allowed values.                          |
+--------------------------------+-----------------------------------------------------------------+
| :param:`root`                  | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| Path of the effective GOROOT. If :param:`stdlib` is set, this is the same                        |
| as ``go.stdlib.root_file.dirname``. Otherwise, this is the same as                               |
| ``go.sdk.root_file.dirname``.                                                                    |
+--------------------------------+-----------------------------------------------------------------+
| :param:`go`                    | :type:`File`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| The main "go" binary used to run go sdk tools.                                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`stdlib`                | :type:`GoStdLib`                                                |
+--------------------------------+-----------------------------------------------------------------+
| The standard library and tools to use in this build mode. This may be the                        |
| pre-compiled standard library that comes with the SDK, or it may be compiled                     |
| in a different directory for this mode.                                                          |
+--------------------------------+-----------------------------------------------------------------+
| :param:`actions`               | :type:`ctx.actions`                                             |
+--------------------------------+-----------------------------------------------------------------+
| The actions structure from the Bazel context, which has all the methods for building new         |
| bazel actions.                                                                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`exe_extension`         | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The suffix to use for all executables in this build mode. Mostly used when generating the output |
| filenames of binary rules.                                                                       |
+--------------------------------+-----------------------------------------------------------------+
| :param:`shared_extension`      | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The suffix to use for shared libraries in this build mode. Mostly used when                      |
| generating output filenames of binary rules.                                                     |
+--------------------------------+-----------------------------------------------------------------+
| :param:`crosstool`             | :type:`list of File`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The files you need to add to the inputs of an action in order to use the cc toolchain.           |
+--------------------------------+-----------------------------------------------------------------+
| :param:`package_list`          | :type:`File`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| A file that contains the package list of the standard library.                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`env`                   | :type:`dict of string to string`                                |
+--------------------------------+-----------------------------------------------------------------+
| Environment variables to pass to actions. Includes ``GOARCH``, ``GOOS``,                         |
| ``GOROOT``, ``GOROOT_FINAL``, ``CGO_ENABLED``, and ``PATH``.                                     |
+--------------------------------+-----------------------------------------------------------------+
| :param:`tags`                  | :type:`list of string`                                          |
+--------------------------------+-----------------------------------------------------------------+
| List of build tags used to filter source files.                                                  |
+--------------------------------+-----------------------------------------------------------------+

Methods
^^^^^^^

* Action generators

  * archive_
  * asm_
  * binary_
  * compile_
  * cover_
  * link_
  * pack_

* Helpers

  * args_
  * `declare_file`_
  * `library_to_source`_
  * `new_library`_


archive
+++++++

This emits actions to compile Go code into an archive.  It supports embedding,
cgo dependencies, coverage, and assembling and packing .s files.

It returns a GoArchive_.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`source`                | :type:`GoSource`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The GoSource_ that should be compiled into an archive.                                           |
+--------------------------------+-----------------------------+-----------------------------------+


asm
+++

The asm function adds an action that runs ``go tool asm`` on a source file to
produce an object, and returns the File of that object.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`source`                | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A source code artifact to assemble.                                                              |
| This must be a ``.s`` file that contains code in the platform neutral `go assembly`_ language.   |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`hdrs`                  | :type:`File iterable`       | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The list of .h files that may be included by the source.                                         |
+--------------------------------+-----------------------------+-----------------------------------+


binary
++++++

This emits actions to compile and link Go code into a binary.  It supports
embedding, cgo dependencies, coverage, and assembling and packing .s files.

It returns a tuple containing GoArchive_, the output executable file, and
a ``runfiles`` object.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The base name of the generated binaries. Required if :param:`executable` is not given.           |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`source`                | :type:`GoSource`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The GoSource_ that should be compiled and linked.                                                |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`test_archives`         | :type:`list GoArchiveData`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| List of archives for libraries under test. See link_.                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_linkopts`           | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Go link options.                                                                                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`version_file`          | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| Version file used for link stamping. See link_.                                                  |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`info_file`             | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| Info file used for link stamping. See link_.                                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`executable`            | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| Optional output file to write. If not set, ``binary`` will generate an output                    |
| file name based on ``name``, the target platform, and the link mode.                             |
+--------------------------------+-----------------------------+-----------------------------------+

compile
+++++++

The compile function adds an action that compiles a list of source files into
a package archive (.a file).

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sources`               | :type:`File iterable`       | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of source code artifacts.                                                            |
| These must be pure .go files, no assembly or cgo is allowed.                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importpath`            | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The import path this package represents. This is passed to the -p flag. When the actual import   |
| path is different than the source import path (i.e., when ``importmap`` is set in a              |
| ``go_library`` rule), this should be the actual import path.                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`archives`              | :type:`GoArchive iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of all directly imported libraries.                                                  |
| The action will verify that all directly imported libraries were supplied, not allowing          |
| transitive dependencies to satisfy imports. It will not check that all supplied libraries were   |
| used though.                                                                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`out_lib`               | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The archive file that should be produced.                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`out_export`            | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| File where extra information about the package may be stored. This is used                       |
| by nogo to store serialized facts about definitions. In the future, it may                       |
| be used to store export data (instead of the .a file).                                           |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_goopts`             | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Additional flags to pass to the compiler.                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`testfilter`            | :type:`string`              | :value:`"off"`                    |
+--------------------------------+-----------------------------+-----------------------------------+
| Controls how files with a ``_test`` suffix are filtered.                                         |
|                                                                                                  |
| * ``"off"`` - files with and without a ``_test`` suffix are compiled.                            |
| * ``"only"`` - only files with a ``_test`` suffix are compiled.                                  |
| * ``"exclude"`` - only files without a ``_test`` suffix are compiled.                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`asmhdr`                | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| If provided, the compiler will write an assembly header to this file.                            |
+--------------------------------+-----------------------------+-----------------------------------+


cover
+++++

The cover function adds an action that runs ``go tool cover`` on a set of source
files to produce copies with cover instrumentation.

Returns a covered GoSource_ with the required source files process for coverage.

Note that this removes most comments, including cgo comments.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`source`                | :type:`GoSource`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The source object to process. Any source files in the object that have been marked as needing    |
| coverage will be processed and substiuted in the returned GoSource.                              |
+--------------------------------+-----------------------------+-----------------------------------+


link
++++

The link function adds an action that runs ``go tool link`` on a library.

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`archive`               | :type:`GoArchive`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The library to link.                                                                             |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`test_archives`         | :type:`GoArchiveData list`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| List of archives for libraries under test. These are excluded from linking                       |
| if transitive dependencies of :param:`archive` have the same package paths.                      |
| This is useful for linking external test archives that depend internal test                      |
| archives.                                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`executable`            | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The binary to produce.                                                                           |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_linkopts`           | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Basic link options, these may be adjusted by the :param:`mode`.                                  |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`version_file`          | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| Version file used for link stamping.                                                             |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`info_file`             | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| Info file used for link stamping.                                                                |
+--------------------------------+-----------------------------+-----------------------------------+

pack
++++

The pack function adds an action that produces an archive from a base archive
and a collection of additional object files.

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`in_lib`                | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The archive that should be copied and appended to.                                               |
| This must always be an archive in the common ar form (like that produced by the go compiler).    |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`out_lib`               | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The archive that should be produced.                                                             |
| This will always be an archive in the common ar form (like that produced by the go compiler).    |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`objects`               | :type:`File iterable`       | :value:`()`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of object files to be added to the output archive file.                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`archives`              | :type:`list of File`        | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Additional archives whose objects will be appended to the output.                                |
| These can be ar files in either common form or either the bsd or sysv variations.                |
+--------------------------------+-----------------------------+-----------------------------------+

args
++++

This creates a new Args_ object, using the ``ctx.actions.args`` method. The
object is pre-populated with standard arguments used by all the go toolchain
builders.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+

declare_file
++++++++++++

This is the equivalent of ``ctx.actions.declare_file``. It uses the
current build mode to make the filename unique between configurations.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`path`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A path for this file, including the basename of the file.                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ext`                   | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The extension to use for the file.                                                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A name to use for this file. If path is not present, this becomes a prefix to the path.          |
| If this is not set, the current rule name is used in it's place.                                 |
+--------------------------------+-----------------------------+-----------------------------------+

library_to_source
+++++++++++++++++

This is used to build a GoSource object for a given GoLibrary in the current
build mode.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`attr`                  | :type:`ctx.attr`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The attributes of the target being analyzed. For most rules, this should be                      |
| ``ctx.attr``. Rules can also pass in a ``struct`` with the same fields.                          |
|                                                                                                  |
| ``library_to_source`` looks for fields corresponding to the attributes of                        |
| ``go_library`` and ``go_binary``. This includes ``srcs``, ``deps``, ``embed``,                   |
| and so on. All fields are optional (and may not be defined in the struct                         |
| argument at all), but if they are present, they must have the same types and                     |
| allowed values as in ``go_library`` and ``go_binary``. For example, ``srcs``                     |
| must be a list of ``Targets``; ``gc_goopts`` must be a list of strings.                          |
|                                                                                                  |
| As an exception, ``deps``, if present, must be a list containing either                          |
| ``Targets`` or ``GoArchives``.                                                                   |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`library`               | :type:`GoLibrary`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The GoLibrary_ that you want to build a GoSource_ object for in the current build mode.          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`coverage_instrumented` | :type:`bool`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This controls whether cover is enabled for this specific library in this mode.                   |
| This should generally be the value of ctx.coverage_instrumented()                                |
+--------------------------------+-----------------------------+-----------------------------------+

new_library
+++++++++++

This creates a new GoLibrary.  You can add extra fields to the go library by
providing extra named parameters to this function, they will be visible to the
resolver when it is invoked.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`resolver`              | :type:`function`            | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| This is the function that gets invoked when converting from a GoLibrary to a GoSource.           |
| The function's signature must be                                                                 |
|                                                                                                  |
| .. code:: bzl                                                                                    |
|                                                                                                  |
|     def _testmain_library_to_source(go, attr, source, merge)                                     |
|                                                                                                  |
| attr is the attributes of the rule being processed                                               |
| source is the dictionary of GoSource fields being generated                                      |
| merge is a helper you can call to merge                                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importable`            | :type:`bool`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This controls whether the GoLibrary_ is supposed to be importable. This is generally only false  |
| for the "main" libraries that are built just before linking.                                     |
+--------------------------------+-----------------------------+-----------------------------------+
