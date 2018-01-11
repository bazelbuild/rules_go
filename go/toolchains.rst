Go toolchains
=============

.. _core: core.bzl
.. _forked version of Go: `Registering a custom SDK`_
.. _control the version: `Forcing the Go version`_
.. _installed sdk: `Using the installed Go sdk`_
.. _go sdk rules: `The SDK`_
.. _Go website: https://golang.org/
.. _binary distribution: https://golang.org/dl/
.. _cross compiling: crosscompile.rst
.. _register: Registration_
.. _register_toolchains: https://docs.bazel.build/versions/master/skylark/lib/globals.html#register_toolchains
.. _compilation modes: modes.rst#compilation-modes
.. _go assembly: https://golang.org/doc/asm
.. _GoLibrary: providers.rst#GoLibrary
.. _GoSource: providers.rst#GoSource
.. _GoArchive: providers.rst#GoArchive

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

The Go toolchain is at the heart of the Go rules, and is the mechanism used to
customize the behavior of the core_ Go rules.

.. contents:: :depth: 2

-----

Design
------

The Go toolchain consists of three main layers, `the sdk`_ and `the toolchain`_ and `the context`_.

The SDK
~~~~~~~

At the bottom is the Go SDK. This is the same thing you would get if you go to the main
`Go website`_ and download a `binary distribution`_.

This is always bound to ``@go_sdk`` and can be referred to directly if needed, but in general
you should always access it through the toolchain.

The go_download_sdk_, go_host_sdk_ and go_local_sdk_ family of rules are responsible for downloading
these, and adding just enough of a build file to expose the contents to Bazel.
It currently also builds the cross compiled standard libraries for specific combinations, although
we hope to make that an on demand step in the future.

SDKs are specific to the host they are running on and the version of Go they want to use
but not the target they compile for. The Go SDK is naturally `cross compiling`_.

If you don't do anything special, the Go rules will download the most recent official SDK for
your host.
If you need a `forked version of Go`_\, want to `control the version`_ or just use the
`installed sdk`_ then it is easy to do, you just need to make sure you have bound the go_sdk
repository before you call go_register_toolchains_.

The toolchain
~~~~~~~~~~~~~

This a wrapper over the sdk that provides enough extras to match, target and work on a specific
platforms. It should be considered an opaqute type, you only ever use it through `the context`_.

Declaration
^^^^^^^^^^^

Toolchains are declared using the go_toolchain_ macro. This actually registers two Bazel
toolchains, the main Go toolchain, and a special bootstrap toolchain. The bootstrap toolchain
is needed because the full toolchain includes tools that are compiled on demand and written in
go, so we need a special cut down version of the toolchain to build those tools.

Toolchains are pre-declared for all the known combinations of host and target, and the names
are a predictable
"<**host**>"
for host toolchains and
"<**host**>_cross\_<**target**>"
for cross compilation toolchains. So for instance if the rules_go repository is loaded with
it's default name, the following toolchain labels (along with many others) will be available

.. code::

  @io_bazel_rules_go//go/toolchain:linux_amd64
  @io_bazel_rules_go//go/toolchain:linux_amd64-bootstrap
  @io_bazel_rules_go//go/toolchain:linux_amd64_cross_windows_amd64

The toolchains are not usable until you register_ them.

Registration
^^^^^^^^^^^^

Normally you would just call go_register_toolchains_ from your WORKSPACE to register all the
pre-declared toolchains, and allow normal selection logic to pick the right one.

It is fine to add more toolchains to the available set if you like. Because the normal
toolchain matching mechanism prefers the first declared match, you can also override individual
toolchains by declaring and registering toolchains with the same constraints *before* calling
go_register_toolchains_.

If you wish to have more control over the toolchains you can instead just make direct
calls to register_toolchains_ with only the toolchains you wish to install. You can see an
example of this in `limiting the available toolchains`_.
It is important to note that you **must** also register the boostrap toolchain for any other
toolchain that you register, otherwise the tools for that toolchain cannot be built.



The context
~~~~~~~~~~~

This is the type you use if you are writing custom rules that need

Use
^^^

If you are writing a new rule that wants to use the Go toolchain, you need to do a couple of things.
First, you have to declare that you want to consume the toolchain on the rule declaration.

.. code:: bzl

  my_rule = rule(
      _my_rule_impl,
      attrs = {
          ...
          "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_context_data")),
      },
      toolchains = ["@io_bazel_rules_go//go:toolchain"],
  )

And then in the rule body, you need to get the toolchain itself and use it's action generators.

.. code:: bzl

  def _my_rule_impl(ctx):
    go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
    srcs, vars = go_toolchain.actions.cover(ctx, go_toolchain, ctx.files.srcs)


Customizing
-----------

Normal usage
~~~~~~~~~~~~

This is an example of normal usage for the other examples to be compared against.
This will download and use the latest Go SDK that was available when the version of rules_go
you're using was released.

WORKSPACE
^^^^^^^^^

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()
    go_register_toolchains()


Forcing the Go version
~~~~~~~~~~~~~~~~~~~~~~

You can select the version of the Go SDK to use by specifying it when you call
go_register_toolchains_ but you must use a value that matches a known toolchain.

WORKSPACE
^^^^^^^^^

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()
    go_register_toolchains(go_version="1.7.5")


Using the installed Go SDK
~~~~~~~~~~~~~~~~~~~~~~~~~~

The "host" version is a special toolchain that breaks the hermetic seal to use the host installed
toolchain.

WORKSPACE
^^^^^^^^^

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()
    go_register_toolchains(go_version="host")



Registering a custom SDK
~~~~~~~~~~~~~~~~~~~~~~~~

If you want to register your own toolchain that takes precedence over the pre-declared ones you can
just add it and register it before the normal ones.

WORKSPACE
^^^^^^^^^

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains", "go_download_sdk")

    go_download_sdk(name="my_linux_sdk", url="https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz")
    register_toolchains(
        "@//:my_linux_toolchain", "@//:my_linux_toolchain-bootstrap",
    )

    go_rules_dependencies()
    go_register_toolchains()


BUILD.bazel
^^^^^^^^^^^

.. code:: bzl

    go_toolchain(name="my_linux_toolchain", sdk="my_linux_sdk", target="linux_amd64")


Limiting the available toolchains
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you wanted to only allow your project to be compiled on mac at version 1.8.3,
instead of calling go_register_toolchains you can put

WORKSPACE
^^^^^^^^^

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies")

    go_rules_dependencies()
    register_toolchains(
        "@io_bazel_rules_go//go/toolchain:1.8.3_darwin_amd64",
        "@io_bazel_rules_go//go/toolchain:1.8.3_darwin_amd64-bootstrap",
    )


API
---

go_register_toolchains
~~~~~~~~~~~~~~~~~~~~~~

Installs the Go toolchains. If :param:`go_version` is specified, it sets the
SDK version to use (for example, :value:`"1.8.2"`). By default, the latest
SDK will be used.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_version`            | :type:`string`              | :value:`"1.9.2"`                  |
+--------------------------------+-----------------------------+-----------------------------------+
| This specifies the Go version to select.                                                         |
| It will match the version specification of the toochain which for normal sdk toolchains is       |
| also the string part of the `binary distribution`_ you want to use.                              |
| You can also use it to select the "host" sdk toolchain, or a custom toolchain with a             |
| specialized version string.                                                                      |
+--------------------------------+-----------------------------+-----------------------------------+

go_download_sdk
~~~~~~~~~~~~~~~

This downloads a Go SDK for use in toolchains.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this sdk. This should almost always be :value:`go_sdk` if you want the SDK     |
| to be used by toolchains.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`urls`                  | :type:`string_list`         | :value:`official distributions`   |
+--------------------------------+-----------------------------+-----------------------------------+
| A list of mirror urls to the binary distribution of a Go SDK. These must contain the `{}`        |
| used to substitute the sdk filename being fetched (using `.format`.                              |
| It defaults to the official repository :value:`"https://storage.googleapis.com/golang/{}"`.      |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`strip_prefix`          | :type:`string`              | :value:`"go"`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| A directory prefix to strip from the extracted files.                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sdks`                  | :type:`string_list_dict`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This consists of a set of mappings from the host platform tuple to a list of filename and        |
| sha256 for that file. The filename is combined the :param:`urls` to produce the final download   |
| urls to use.                                                                                     |
|                                                                                                  |
| As an example:                                                                                   |
|                                                                                                  |
| .. code:: bzl                                                                                    |
|                                                                                                  |
|     go_download_sdk(                                                                             |
|         name = "go_sdk",                                                                         |
|         sdks = {                                                                                 |
|             "linux_amd64":   ("go1.8.1.linux-amd64.tar.gz",                                      |
|                 "a579ab19d5237e263254f1eac5352efcf1d70b9dacadb6d6bb12b0911ede8994"),             |
|             "darwin_amd64":      ("go1.8.1.darwin-amd64.tar.gz",                                 |
|                 "25b026fe2f4de7c80b227f69588b06b93787f5b5f134fbf2d652926c08c04bcd"),             |
|         },                                                                                       |
|     )                                                                                            |
|                                                                                                  |
+--------------------------------+-----------------------------+-----------------------------------+


go_host_sdk
~~~~~~~~~~~

This detects the host Go SDK for use in toolchains.

It first checks the GOROOT and then searches the PATH. You can achive the same result by setting
the version to "host" when registering toolchains to select the `installed sdk`_ so it should
never be neccesary to use this feature directly.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this sdk. This should almost always be :value:`go_sdk` if you want the SDK     |
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
| A unique name for this sdk. This should almost always be :value:`go_sdk` if you want the SDK     |
| to be used by toolchains.                                                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`path`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The local path to a pre-installed Go SDK. The path must contain the go binary, the tools it      |
| invokes and the standard library sources.                                                        |
+--------------------------------+-----------------------------+-----------------------------------+


go_toolchain
~~~~~~~~~~~~

This adds a toolchain of type :value:`"@io_bazel_rules_go//go:toolchain"` and also a bootstrapping
toolchain of type :value:`"@io_bazel_rules_go//go:bootstrap_toolchain"`.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for the toolchain.                                                                 |
| The base toolchain will have the name you supply, the bootstrap toolchain with have              |
| :value:`"-bootstrap"` appended.                                                                  |
| You will need to use this name when registering the toolchain in the WORKSPACE.                  |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`target`                | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This specifies the target platform tuple for this toolchain.                                     |
|                                                                                                  |
| It should be in the form *GOOS*_*GOARCH* and is used for both names and constraint matching.     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`host`                  | :type:`string`              | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| This is the host platform tuple.                                                                 |
| If it is not set, it defaults to the same as target.                                             |
| If it is set to a different value to target, then this is declaring a cross-compiling toolchain. |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sdk`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This is the name of the SDK to use for this toolchain.                                           |
| The SDK must have been registered using one of the `go sdk rules`_.                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`constraints`           | :type:`label_list`          | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This list is added to the host and or target constraints when declaring the toolchains.          |
| It allows the declaration f additional constraints that must be matched for the toolchain to     |
| be automatically selected.                                                                       |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`link_flags`            | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The link flags are directly exposed on the toolchain.                                            |
| They can be used to specify target specific flags that Go linking actions should apply when      |
| using this toolchain.                                                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`cgo_link_flags`        | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The cgo link flags are directly exposed on the toolchain.                                        |
| They can be used to specify target specific flags that c linking actions generated by cgo        |
| should apply when using this toolchain.                                                          |
+--------------------------------+-----------------------------+-----------------------------------+

go_context
~~~~~~~~~~

This collects the information needed to form and return a :type:`GoContext` from a rule ctx.
It uses the attrbutes and the toolchains.
It can only be used in the implementation of a rule that has the go toolchain attached and
the go context data as an attribute.

.. code:: bzl

  my_rule = rule(
      _my_rule_impl,
      attrs = {
          ...
          "_go_context_data": attr.label(default=Label("@io_bazel_rules_go//:go_context_data")),
      },
      toolchains = ["@io_bazel_rules_go//go:toolchain"],
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

GoContext is never returned by a rule, instead you build one using go_context(ctx) in the top of
any custom skylark rule that wants to interact with the go rules.
It provides all the information needed to create go actions, and create or interact with the other
go providers.

When you get a GoContext from a context (see use_) it exposes a number of fields and methods.

All methods take the GoContext as the only positional argument, all other arguments even if
mandatory must be specified by name, to allow us to re-order and deprecate individual parameters
over time.


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
    * declare_file_
    * library_to_source_
    * new_library_


Fields
^^^^^^

+--------------------------------+-----------------------------------------------------------------+
| **Name**                       | **Type**                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`toolchain`             | :type:`GoToolchain`                                             |
+--------------------------------+-----------------------------------------------------------------+
| The underlying toolchain. This should be considered an opaque type subject to change.            |
+--------------------------------+-----------------------------------------------------------------+
| :param:`mode`                  | :type:`Mode`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| Controls the compilation setup affecting things like enabling profilers and sanitizers.          |
| See `compilation modes`_ for more information about the allowed values.                          |
+--------------------------------+-----------------------------------------------------------------+
| :param:`go`                    | :type:`File`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| The main "go" binary used to run go sdk tools.                                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`root`                  | :type:`string`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The GOROOT value to use.                                                                         |
+--------------------------------+-----------------------------------------------------------------+
| :param:`stdlib`                | :type:`GoStdlib`                                                |
+--------------------------------+-----------------------------------------------------------------+
| The standard library and tools to use in this build mode.                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`sdk_files`             | :type:`list of File`                                            |
+--------------------------------+-----------------------------------------------------------------+
| This is the full set of files exposed by the sdk. You should never need this, it is mainly used  |
| when compiling the standard library.                                                             |
+--------------------------------+-----------------------------------------------------------------+
| :param:`sdk_tools`             | :type:`list of File`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The set of tool binaries exposed by the sdk. You may need this as inputs to a rule that uses     |
| `go tool`                                                                                        |
+--------------------------------+-----------------------------------------------------------------+
| :param:`actions`               | :type:`ctx.actions`                                             |
+--------------------------------+-----------------------------------------------------------------+
| The actions structure from the Bazel context, which has all the methods for building new         |
| bazel actions.                                                                                   |
+--------------------------------+-----------------------------------------------------------------+
| :param:`exe_extension`         | :type:`String`                                                  |
+--------------------------------+-----------------------------------------------------------------+
| The suffix to use for all executables in this build mode. Mostly used when generating the output |
| filenames of binary rules.                                                                       |
+--------------------------------+-----------------------------------------------------------------+
| :param:`crosstool`             | :type:`list of File`                                            |
+--------------------------------+-----------------------------------------------------------------+
| The files you need to add to the inputs of an action in order to use the cc toolchain.           |
+--------------------------------+-----------------------------------------------------------------+
| :param:`package_list`          | :type:`File`                                                    |
+--------------------------------+-----------------------------------------------------------------+
| A file that contains the package list of the standard library.                                   |
+--------------------------------+-----------------------------------------------------------------+


archive
~~~~~~~

This emits actions to compile Go code into an archive.
It supports embedding, cgo dependencies, coverage, and assembling and packing .s files.

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
~~~

The asm function adds an action that runs ``go tool asm`` on a source file
to produce an object, and returns the File of that object.

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
~~~~~~

This emits actions to compile and link Go code into a binary.
It supports embedding, cgo dependencies, coverage, and assembling and packing .s files.

It returns GoLibrary_.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The base name of the generated binaries.                                                         |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`source`                | :type:`GoSource`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The GoSource_ that should be compiled and linked.                                                |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_linkopts`           | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Basic link options.                                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`x_defs`                | :type:`map`                 | :value:`{}`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Link defines, including build stamping ones.                                                     |
+--------------------------------+-----------------------------+-----------------------------------+


compile
~~~~~~~

The compile function adds an action that runs ``go tool compile`` on a set of source files
to produce an archive.

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
| These Must be pure .go files, no assembly or cgo is allowed.                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importpath`            | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The import path this package represents. This is passed to the -p flag.                          |
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
| :param:`gc_goopts`             | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Additional flags to pass to the compiler.                                                        |
+--------------------------------+-----------------------------+-----------------------------------+


cover
~~~~~

The cover function adds an action that runs ``go tool cover`` on a set of source files
to produce copies with cover instrumentation.

Returns a tuple of a covered GoSource with the required source files processed for cover and
the cover vars that were added.

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
~~~~

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
| :param:`executable`            | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The binary to produce.                                                                           |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_linkopts`           | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Basic link options, these may be adjusted by the :param:`mode`.                                  |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`x_defs`                | :type:`map`                 | :value:`{}`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Link defines, including build stamping ones.                                                     |
+--------------------------------+-----------------------------+-----------------------------------+

pack
~~~~

The pack function adds an action that produces an archive from a base archive and a collection
of additional object files.

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
| :param:`archive`               | :type:`File`                | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| An additional archive whose objects will be appended to the output.                              |
| This can be an ar file in either common form or either the bsd or sysv variations.               |
+--------------------------------+-----------------------------+-----------------------------------+



args
~~~~

This creates a new args object, using the ctx.args method, and the populates it with the standard
arguments used by all the go toolchain builders.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+

declare_file
~~~~~~~~~~~~

This is the equivalent of ctx.actions.declare_file except it uses the current build mode to make
the filename unique between configurations.

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
~~~~~~~~~~~~~~~~~

This is used to build a GoSource object for a given GoLibrary in the current build mode.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go`                    | :type:`GoContext`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same GoContext object you got this function from.                               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`attr`                  | :type:`ctx.attr`            | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The attributes of the rule being processed, in a normal rule implementation this would be        |
| ctx.attr.                                                                                        |
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
~~~~~~~~~~~

This creates a new GoLibrary.
You can add extra fields to the go library by providing extra named parameters to this function,
they will be visible to the resolver when it is invoked.

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
