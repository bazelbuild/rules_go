Build modes
===========

.. _go_library: core.rst#go_library
.. _go_binary: core.rst#go_binary
.. _go_test: core.rst#go_test
.. _toolchain: toolchains.rst#the-toolchain-object

.. contents:: :depth: 2

Overview
--------

There are a few modes in which the core go rules can be run, and the selection
mechanism depends on the nature of the variation.

Build modes can be selected either on the command line, or controlled on the
go_binary and go_test rules using `mode attributes`_.

The `command line`_ sets defaults that affect all rules, but explicit settings on
a rule always override the command line. Not all build modes can be controlled
in both places.


Command line
~~~~~~~~~~~~

On the command line, there are a few mechanisms that influence the build mode.

+---------------------+------------------------------------------------------------------+
| --features          | Controls race_, static_, msan_ and pure_, see features_          |
+---------------------+------------------------------------------------------------------+
| --cpu               | Controls GOOS_ GOARCH_, also forces pure_ for cross compilation  |
+---------------------+------------------------------------------------------------------+
| --compilation_mode  | Controls debug_ and strip_                                       |
+---------------------+------------------------------------------------------------------+
| --strip             |  Controls strip_                                                 |
+---------------------+------------------------------------------------------------------+


Features
~~~~~~~~

Features are normally off, unless you select them with :code:`--features=featurename` on the bazel
command line. Features are generic tags that affect *all* rules, not just the ones you specify or
even just the go ones, and any feature can be interpreted by any rule. There is also no protections
that two different rules will not intepret the same feature in very different ways, and no way for
rule authors to protect against that, so it is up to the user when specifying a feature on the
command line to know what it's affects will be on all the rules in their build.

Available features that affect the go rules are:

* race_
* static_
* msan_
* pure_

Mode attributes
~~~~~~~~~~~~~~~

Only rules that link accept build mode controlling attributes (go_binary_ and go_test_, not go_library_).
The entire transitive set of libraries that a leaf depends on are built in the mode specified by
the binary rule. The compiled libraries are distinct and multiple modes can be built in a single pass,
but are shared between leaves building in the same mode.

Currently only static_, pure_, goos_ and goarch_ can be specified as attributes.
Both of these can take one of the values "on", "off" or "auto", and "auto" is the default.

+--------------+-------------------------------------------------------------------------+
| on           | Forces the feature to be turned on for this binary.                     |
+--------------+-------------------------------------------------------------------------+
| off          | This forces the feature to be turned off for the binary even if it is   |
|              | enabled on the command line.                                            |
+--------------+-------------------------------------------------------------------------+
| auto         | The default, it means obey whatever the command line suggests.          |
+--------------+-------------------------------------------------------------------------+

The mode structure
~~~~~~~~~~~~~~~~~~

The build mode structure is handed to all low level go build action. It has the
following fields that control the bevhaviour of those actions:

* static_
* race_
* msan_
* pure_
* link_
* debug_
* strip_
* goos_
* goarch_

Build modes
-----------

The following is a description of the build modes. Not all build modes are truly independent, but
most combinations are valid.

static
~~~~~~

Causes any cgo code to be statically linked in to the go binary.

race
~~~~

Causes the binary to be built with race detection enabled. Most often used when
running tests.

msan
~~~~

Causes go code to be built with support for the clang memory sanitizer.

pure
~~~~

Compiles go code with :code:`CGO_ENABLED=0`. Mostly often used to force go code to not
link against libc.

link
~~~~

| This is not yet working, and there is no mechaism to actually control the link mode,
| so it is always the default value of "normal"

Controls the linking mode, must be one of

+--------------+------------------------------------------------------------------+
| normal       | This is the default, builds executables.                         |
+--------------+------------------------------------------------------------------+
| shared       | Links to a shared go library.                                    |
+--------------+------------------------------------------------------------------+
| c-shared     | Links to a shared c library.                                     |
+--------------+------------------------------------------------------------------+
| pie          | Links a position independent executables                         |
+--------------+------------------------------------------------------------------+
| plugin       | Links to a go plugin.                                            |
+--------------+------------------------------------------------------------------+

debug
~~~~~

This compiles with full support for debugging, specifically it compiles with
optimizations disabled and inlining off.

strip
~~~~~

Causes debugging information to be stripped from the binaries.

goos
~~~~

This controls which operating system to target.

goarch
~~~~~~

This controls which architecture to target.

Using build modes
-----------------


Building pure go binaries
~~~~~~~~~~~~~~~~~~~~~~~~~

You can switch the default binaries to non cgo using

.. code:: bash

    bazel build --features=pure //:my_binary

You can build pure go binaries by setting those attributes on a binary.

.. code:: bzl

    go_binary(
        name = "foo",
        srcs = ["foo.go"],
        pure = "on",
    )


Building static binaries
~~~~~~~~~~~~~~~~~~~~~~~~

| Note that static linking does not work on darwin.

You can switch the default binaries to statically linked binaries using

.. code:: bash

    bazel build --features=static //:my_binary

You can build static go binaries by setting those attributes on a binary.
If you want it to be fully static (no libc), you should also specify pure.

.. code:: bzl

    go_binary(
        name = "foo",
        srcs = ["foo.go"],
        static = "on",
    )


Using the race detector
~~~~~~~~~~~~~~~~~~~~~~~

You can switch the default binaries to race detection mode, and thus also switch
the mode of tests by using

.. code::

    bazel test --features=race //...

but in general it is strongly recommended instead to turn it on for specific tests.

.. code::

    go_test(
        name = "go_default_test",
        srcs = ["lib_test.go"],
        embed = [":go_default_library"],
        race = "on",
  )

