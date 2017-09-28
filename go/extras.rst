Extra rules
===========

.. _`core go rules`: core.rst
.. _go_repository: workspace.rst#go_repository
.. _`gazelle documentation`: tools/gazelle/README.md

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

This rule should only occur once in the top level build file.
Running

.. code::
  
  bazel run //:gazelle

will cause gazelle to run with the supplied options in the source tree at the root.
See the `gazelle documentation`_ for more details.

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`command`           | :type:`string`              | :value:`update`                       |
+----------------------------+-----------------------------+---------------------------------------+
| Controls the basic mode of operation gazelle runs in.                                            |
|                                                                                                  |
| * :value:`update` : Gazelle will create new BUILD files or update existing BUILD files if        |
|   needed.                                                                                        |
| * :value:`fix` : In addition to the changes made in update, Gazelle will make potentially        |
|   breaking changes.                                                                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`mode`              | :type:`string`              | :value:`fix`                          |
+----------------------------+-----------------------------+---------------------------------------+
| Controls the action gazelle takes when it detects files that are out of date.                    |
|                                                                                                  |
| * :value:`print` : prints all of the updated BUILD files.                                        |
| * :value:`fix` : rewrites all of the BUILD files in place.                                       |
| * :value:`diff` : computes the rewrite but then just does a diff.                                |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`external`          | :type:`string`              | :value:`external`                     |
+----------------------------+-----------------------------+---------------------------------------+
| Controls how gazelle resolves import paths to labels.                                            |
|                                                                                                  |
| * :value:`external` - resolve external packages with go_repository_                              |
| * :value:`vendored` - resolve external packages as packages in vendor                            |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`build_tags`        | :type:`string_list`         | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| A list of build tags. If not specified, Gazelle will not filter sources with build constraints.  |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`args`              | :type:`string_list`         | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| Arguments to forward to gazelle.                                                                 |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`prefix`            | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The prefix of the target workspace. This is path fragement fom the GOPATH to your repository if  |
| it were checked out with the normal go tools. It is combined the workspace relative path when    |
| guessing the import path of a library.                                                           |
+----------------------------+-----------------------------+---------------------------------------+

go_embed_data
-------------

go_embed_data generates a .go file that contains data from a file or a list of files.
It should be consumed in the srcs list of one of the `core go rules`_.

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`out`               | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| File name of the .go file to generate.                                                           |
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
| :param:`flatten`           | :type:`boolean`             | :value:`false`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`true` and :param:`srcs` is used, map keys are file base names instead of relative     |
| paths.                                                                                           |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`string`            | :type:`boolean`             | :value:`false`                        |
+----------------------------+-----------------------------+---------------------------------------+
| If :value:`true`, the embedded data will be stored as :type:`string` instead of :type:`[]byte`.  |
+----------------------------+-----------------------------+---------------------------------------+
        
       
