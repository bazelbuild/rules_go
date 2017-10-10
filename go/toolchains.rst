Go toolchains
=============

.. _core: core.bzl
.. _forked version of Go: `Using a custom sdk`_
.. _control the version: `Forcing the Go version`_
.. _installed sdk: `Using the installed Go sdk`_
.. _Go website: https://golang.org/
.. _binary distribution: https://golang.org/dl/
.. _cross compiling: crosscompile.rst
.. _register: Registration_
.. _register_toolchains: https://docs.bazel.build/versions/master/skylark/lib/globals.html#register_toolchains
.. _compilation modes: modes.rst#compilation-modes
.. _go assembly: https://golang.org/doc/asm

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

The Go toolchain consists of two main layers, `the sdk`_ and `the toolchain`_.

The SDK
~~~~~~~

At the bottom is the Go SDK. This is the same thing you would get if you go to the main
`Go website`_ and download a `binary distribution`_.

The go_sdk_ rule is responsible for downloading these, and adding just enough of a build file
to expose the contents to Bazel. It currently also builds the cross compiled standard libraries
for specific combinations, although we hope to make that an on demand step in the future.

SDKs are specific to the host they are running on and the version of Go they want to use
but not the target they compile for. The Go SDK is naturally `cross compiling`_.

The Go rules already adds a go_sdk_ rule for all the host and Go version pairs that are shipped
on the main Go language website, so there should be no need to declare one of these unless you
need a `forked version of Go`_\, however you may want to `control the version`_ or use the
`installed sdk`_.

The toolchain
~~~~~~~~~~~~~

Declaration
^^^^^^^^^^^

Toolchains are declared using the go_toolchain_ macro. This actually registers two Bazel
toolchains, the main Go toolchain, and a special bootstrap toolchain. The bootstrap toolchain
is needed because the full toolchain includes tools that are compiled on demand and written in
go, so we need a special cut down version of the toolchain to build those tools.

Toolchains are pre-declared for all the known combinations of host, target and sdk, and the names
are a predictable
"<**version**>_<**host**>"
for host toolchains and
"<**version**>_<**host**>_cross\_<**target**>"
for cross compilation toolchains. So for instance if the rules_go repository is loaded with
it's default name, the following toolchain labels (along with many others) will be available

.. code::

  @io_bazel_rules_go//go/toolchain:1.9.0_linux_amd64
  @io_bazel_rules_go//go/toolchain:1.9.0_linux_amd64-bootstrap
  @io_bazel_rules_go//go/toolchain:1.9.0_linux_amd64_cross_windows_amd64

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

Use
^^^

If you are writing a new rule that wants to use the Go toolchain, you need to do a couple of things.
First, you have to declare that you want to consume the toolchain on the rule declaration.

.. code:: bzl

  my_rule = rule(
      _my_rule_impl,
      attrs = {
          ...
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

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains", "go_sdk")

    go_sdk(name="my_linux_sdk", url="https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz")
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
| :param:`go_version`            | :type:`string`              | :value:`"1.9"`                    |
+--------------------------------+-----------------------------+-----------------------------------+
| This specifies the Go version to select.                                                         |
| It will match the version specification of the toochain which for normal sdk toolchains is       |
| also the string part of the `binary distribution`_ you want to use.                              |
| You can also use it to select the "host" sdk toolchain, or a custom toolchain with a             |
| specialized version string.                                                                      |
+--------------------------------+-----------------------------+-----------------------------------+

go_sdk
~~~~~~

This prepares a Go SDK for use in toolchains.

If neither :param:`path` or :param:`urls` is set then go_sdk will attempt to detect the installed
host SDK, first by checking the GO_ROOT and then by searching the PATH.
The `installed sdk`_ toolchain is already available though, so it should never be neccesary to
use this feature directly.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this sdk.                                                                      |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`path`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The local path to a pre-installed Go SDK.                                                        |
|                                                                                                  |
| If :param:`path` is set :param:`urls` must be left empty.                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`urls`                  | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A list of mirror urls to the binary distribution of a Go SDK.                                    |
| You should generally also set the :param:`sha256` parameter when using :param:`urls`.            |
|                                                                                                  |
| If :param:`urls` is set :param:`path` must be left empty.                                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`strip_prefix`          | :type:`string`              | :value:`"go"`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| A directory prefix to strip from the extracted files.                                            |
|                                                                                                  |
| This is only used if :param:`urls` is set, it has no effect on :param:`path`.                    |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sha256`                | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The expected SHA-256 hash of the file downloaded.                                                |
|                                                                                                  |
| This is only used if :param:`urls` is set, it has no effect on :param:`path`.                    |
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
| The SDK must have been registered using go_sdk_.                                                 |
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

The toolchain object
~~~~~~~~~~~~~~~~~~~~

When you get a Go toolchain from a context (see use_) it exposes a number of fields, of those
the stable public interface is

* go_toolchain

  * actions

    * asm_
    * binary_
    * compile_
    * cover_
    * library_
    * link_
    * pack_


The only stable public interface is the actions member.
This holds a collection of functions for generating the standard actions the toolchain knows
about, compiling and linking for instance.
All the other members are there to provide information to those action functions, and the api of
any other part is subject to arbritary breaking changes at any time.

All action functions take the ctx and the go_toolchain as the only positional arguments, all
other arguments even if mandator must be specified by name, to allow us to re-order and
deprecate individual parameters over time.


asm
~~~

The asm function adds an action that runs ``go tool asm`` on a source file
to produce an object.

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
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
| :param:`out_obj`               | :type:`File`                | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The output object file that should be built by the generated action.                             |
+--------------------------------+-----------------------------+-----------------------------------+


binary
~~~~~~

This emits actions to compile and link Go code into a binary.
It supports embedding, cgo dependencies, coverage, and assembling and packing .s files.

It returns a tuple of GoLibrary_ and GoBinary_.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The base name of the generated binaries.                                                         |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`srcs`                  | :type:`File iterable`       | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of Go source Files to be compiled.                                                   |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`deps`                  | :type:`GoLibrary iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The list of direct dependencies of this package.                                                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`cgo_info`              | :type:`CgoInfo`             | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| An optional CgoInfo provider for this library.                                                   |
| There may be at most one of these among the library and its embeds.                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`embed`                 | :type:`GoEmbed iterable`    | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Sources, dependencies, and other information from these are combined with the package            |
| being compiled.                                                                                  |
| Used to build internal test packages.                                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importpath`            | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The import path this package represents.                                                         |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`gc_linkopts`           | :type:`string_list`         | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Basic link options.                                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`x_defs`                | :type:`map`                 | :value:`{}`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Link defines, including build stamping ones.                                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`golibs`                | :type:`GoLibrary iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of GoLibrary_ objects.                                                               |
| Used to pass in synthetic dependencies.                                                          |
+--------------------------------+-----------------------------+-----------------------------------+


compile
~~~~~~~

The compile function adds an action that runs ``go tool compile`` on a set of source files
to produce an archive.

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
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
| :param:`golibs`                | :type:`GoLibrary iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of all directly imported libraries.                                                  |
| The action will verify that all directly imported libraries were supplied, not allowing          |
| transitive dependencies to satisfy imports. It will not check that all supplied libraries were   |
| used though.                                                                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`mode`                  | :type:`string`              | :value:`NORMAL_MODE`              |
+--------------------------------+-----------------------------+-----------------------------------+
| Controls the compilation setup affecting things like enabling profilers and sanitizers.          |
| See `compilation modes`_ for more information about the allowed values.                          |
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

Returns a tuple of the covered source list and the cover vars.

Note that this removes most comments, including cgo comments.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sources`               | :type:`File iterable`       | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of Go source files.                                                                  |
| These Must be pure .go files that are ready to be passed to compile_, no assembly or cgo is      |
| allowed.                                                                                         |
+--------------------------------+-----------------------------+-----------------------------------+


library
~~~~~~~

This emits actions to compile Go code into an archive.
It supports embedding, cgo dependencies, coverage, and assembling and packing .s files.

It returns a tuple of GoLibrary_ and GoEmbed_.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`srcs`                  | :type:`File iterable`       | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of Go source Files to be compiled.                                                   |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`deps`                  | :type:`GoLibrary iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The list of direct dependencies of this package.                                                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`cgo_info`              | :type:`CgoInfo`             | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| An optional CgoInfo provider for this library.                                                   |
| There may be at most one of these among the library and its embeds.                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`embed`                 | :type:`GoEmbed iterable`    | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| Sources, dependencies, and other information from these are combined with the package            |
| being compiled.                                                                                  |
| Used to build internal test packages.                                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`want_coverage`         | :type:`boolean`             | :value:`False`                    |
+--------------------------------+-----------------------------+-----------------------------------+
| A bool indicating whether sources should be instrumented for coverage.                           |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importpath`            | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The import path this package represents.                                                         |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importable`            | :type:`boolean`             | :value:`True`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| A bool indicating whether the package can be imported by other libraries.                        |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`golibs`                | :type:`GoLibrary iterable`  | :value:`[]`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| An iterable of GoLibrary_ objects.                                                               |
| Used to pass in synthetic dependencies.                                                          |
+--------------------------------+-----------------------------+-----------------------------------+


link
~~~~

The link function adds an action that runs ``go tool link`` on a library.

It does not return anything.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`library`               | :type:`GoLibrary`           | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The library to link.                                                                             |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`mode`                  | :type:`string`              | :value:`NORMAL_MODE`              |
+--------------------------------+-----------------------------+-----------------------------------+
| Controls the compilation setup affecting things like enabling profilers and sanitizers.          |
| See `compilation modes`_ for more information about the allowed values.                          |
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
| :param:`ctx`                   | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The current rule context, used to generate the actions.                                          |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`go_toolchain`          | :type:`the Go toolchain`    | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| This must be the same Go toolchain object you got this function from.                            |
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
