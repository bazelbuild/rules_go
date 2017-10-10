Deprecated functionality
========================

.. _proto: /proto/core.rst
.. _go_repository: workspace.rst#go_repository
.. _go_library: core.rst#go_library
.. _nested workspaces: https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html
.. _go_rules_dependencies: workspace.rst#go_rules_dependencies
.. _go_register_toolchains: workspace.rst#go_register_toolchains
.. _#721: https://github.com/bazelbuild/rules_go/issues/721

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

Anything listed in here is functionality that is no longer supported, and will
be removed in a future version. Where possible these functions will also nag
you to remove them during the build.

.. contents:: :depth: 1

new_go_repository
~~~~~~~~~~~~~~~~~

The functionality of this was rolled into go_repository_ quite a while ago, it has been a
straight alias for a few releases, so converting is guaranteed to work.
We will be removing the alias in the near future.

go_proto_library
~~~~~~~~~~~~~~~~

There are two rules of the same name. This is specifically about the one in
:value:`"@io_bazel_rules_go//proto:go_proto_library.bzl"` which use mechanisms
that are not longer supported and not as flexible as the one you load from
:value:`"@io_bazel_rules_go//proto:def.bzl"` which is documented `here <proto>`_.

The new mechanism is very different from the old one, and converting is a non trivial task, but
there are no features of the old system that are not supported by the new one.

The only significant issue you might hit during conversion is that you really need the
``option go_package`` stanza in your proto files now.

cgo_library
~~~~~~~~~~~

Use go_library_ with ``cgo = True`` instead.

All the functionality of cgo_library was subsumed by a normal go_library_. There are no missing
features that we know of, and converting is as simple as switching the rule to go_library_ and
adding the :param:`cgo` parameter with a value of :value:`True`. As such there is no
reason not to switch, and we will be deleting the rule in the very near future.

go_repositories
~~~~~~~~~~~~~~~

This is a compatability wrapper from before toolchain registration was separated from dependency
loading.
This was done because go_register_toolchains_ is a long term api that the user may want to interfere
with or not call, whereas go_rules_dependencies_ is an API that you should always call but will one
day be superseded by `nested workspaces`_.

.. code:: bzl

    go_rules_dependencies()
    go_register_toolchains()


go_prefix
~~~~~~~~~

This is a legacy from when the import path for a go_library_ was determined from the root
go_prefix and the path from the workspace root. Now instead we have every single go_library_
know it's own import path. We currently maintain this rule for backwards compatability, but we
expect to have it removed well before 1.0. See `#721`_.

This declares the common prefix of the import path which is shared by all Go libraries in the
repository.
A go_prefix rule must be declared in the top-level BUILD file for any repository containing
Go rules.
This is used by the Bazel rules during compilation to map import paths to dependencies.
See the |go_prefix_faq|_ for more information.

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`prefix`            | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| Global prefix used to fully qualify all Go targets.                                              |
+----------------------------+-----------------------------+---------------------------------------+
