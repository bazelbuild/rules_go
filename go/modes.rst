Build modes
===========

.. _Output groups: https://docs.bazel.build/versions/master/skylark/rules.html#output-groups
.. _go_library: core.rst#go_library
.. _go_binary: core.rst#go_binary
.. _go_test: core.rst#go_test
.. _filegroup: https://docs.bazel.build/versions/master/be/general.html#filegroup

* `Overview`_
* `Building static binaries`_
* `Using the race detector`_

Overview
--------

There are a few modes in which the core go rules can be run, and the selection 
mechanism depends on the nature of the variation.

The most common selection mechanisms used on the command line are features and 
output groups.

Features
~~~~~~~~

Features are normally off, unless you select them with :code:`--features=featurename` on the bazel
command line. Features are generic tags that affect *all* rules, not just the ones you specify or
even just the go ones, and any feature can be interpreted by any rule. There is also no protections 
that two different rules will not intepret the same feature in very different ways, and no way for
rule authors to protect against that, so it is up to the user when specifying a feature on the
command line to know what it's affects will be on all the rules in their build.

Available features from the go rules are:

* go_test_
    * race

Output groups
~~~~~~~~~~~~~

`Output groups`_ are alternative sets of files produced by the build targets on the command line.
There is a default output group that is built unless you specifically select a
different one.

If you use :code:`--output_groups=groupname` then only that output group will be 
built; if you use :code:`--output_groups=+groupname` then that output group will
be added to the set to be built (note the +).

Output groups may also be used by rules to select files from dependencies. 
Only outputs that are actively selected are built.


Available output groups from the go rules are:

* go_binary_
    * race
    * static
* go_library_
    * race

Building static binaries
------------------------

| Note that static linking does not work on darwin.

You can build statically linked binaries using

.. code:: bash

    bazel build --output_groups=static //:my_binary

You can depend on static binaries (e.g., for packaging) using filegroup_

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
