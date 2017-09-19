Build modes
===========

* `Overview`_
* `Building static binaries`_
* `Using the race detector`_

Overview
--------

There are a few modes in which the core go rules can be run, and the selection 
mechanism depends on the nature of the variation.

Features
~~~~~~~~
The most common selection mechanisms used on the command line are features and 
output groups.

Features are normally off, unless you select them with :code:`--features=featurename`

Available features are:

* race

Output groups
~~~~~~~~~~~~~

There is a default output group that is built unless you specificall select a
different one.

If you use :code:`--output_groups=groupname` then only that output group will be 
built, if you use :code:`--output_groups=+groupname` then that output group will
be added to the set to be built (note the +)

Output groups are also often used inside rules to pick a specify output mode of
the rules. Only outputs that are actively select are built.

Available output groups are:

* race
* static

Building static binaries
------------------------

You can build binaries in static linking mode using

.. code:: bash

    bazel build --output_groups=static //:my_binary

You can depend on static binaries (e.g., for packaging) using ``filegroup``:

.. code:: bzl

    go_binary(
        name = "foo",
        srcs = ["foo.go"],
    )

    filegroup(
        name = "foo_static",
        srcs = [":foo"],
        output_group = "static",
    )

Using the race detector
-----------------------

You can run tests with the race detector enabled using

.. code::

    bazel test --features=race //...

You can build binaries with the race detector enabled using

.. code::

    bazel build --output_groups=race //...

The difference is necessary because the rules for binaries can produce both
race and non-race versions, but tools used during the build should always be
built in the non-race configuration. ``--output_groups`` is needed to select
the configuration of the final binary only. For tests, only one executable
can be tested, and ``--features`` is needed to select the race configuration.
