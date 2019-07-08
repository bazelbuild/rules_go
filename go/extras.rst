Extra rules
===========

.. _`core go rules`: core.rst
.. _go_repository: https://github.com/bazelbuild/bazel-gazelle/blob/master/repository.rst#go_repository
.. _`gazelle documentation`: https://github.com/bazelbuild/bazel-gazelle/blob/master/README.rst
.. _gazelle rule: https://github.com/bazelbuild/bazel-gazelle#bazel-rule
.. _gomock_rule: https://github.com/jmhodges/bazel_gomock
.. _golang/mock: github.com/golang/mock

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

This is a collection of helper rules. These are not core to building a go binary, but are supplied
to make life a little easier.

.. contents::

-----

gazelle
-------

This rule has moved. See `gazelle rule`_ in the Gazelle repository.

gomock
------

This rule allows you to generate mock interfaces with mockgen (from `golang/mock`_) which can be useful for certain testing scenarios. See  `gomock_rule`_ in the gomock repository.

go_embed_data
-------------

``go_embed_data`` generates a .go file that contains data from a file or a
list of files. It should be consumed in the srcs list of one of the
`core go rules`_.

Before using ``go_embed_data``, you must add the following snippet to your
WORKSPACE:

.. code:: bzl

    load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

    go_embed_data_dependencies()


``go_embed_data`` accepts the attributes listed below.

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`package`           | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| Go package name for the generated .go file.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`var`               | :type:`string`              | :value:`"Data"`                       |
+----------------------------+-----------------------------+---------------------------------------+
| Name of the variable that will contain the embedded data.                                        |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`src`               | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| A single file to embed. This cannot be used at the same time as :param:`srcs`.                   |
| The generated file will have a variable of type :type:`[]byte` or :type:`string` with the        |
| contents of this file.                                                                           |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`srcs`              | :type:`string`              | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| A list of files to embed. This cannot be used at the same time as :param:`src`.                  |
| The generated file will have a variable of type :type:`map[string][]byte` or                     |
| :type:`map[string]string` with the contents of each file.                                        |
| The map keys are relative paths the files from the repository root.                              |
| Keys for files in external repositories will be prefixed with :value:`"external/repo/"` where    |
| "repo" is the name of the external repository.                                                   |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`flatten`           | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True` and :param:`srcs` is used, map keys are file base names instead of relative     |
| paths.                                                                                           |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`unpack`            | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True`, sources are treated as archives and their contents will be stored. Supported   |
| formats are `.zip` and `.tar`.                                                                   |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`string`            | :type:`boolean`             | :value:`False`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`True`, the embedded data will be stored as :type:`string` instead of :type:`[]byte`.  |
+----------------------------+-----------------------------+---------------------------------------+
