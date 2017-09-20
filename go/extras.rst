Extra rules
===========

.. _`core go rules`: core.rst
.. _go_repository: workspace.rst#go_repository
.. _`gazelle documentation`: tools/gazelle/README.md

This is a collection of helper rules. These are not core to building a go binary, but are supplied to make life a little 
easier.

* gazelle_
* go_embed_data_

gazelle
-------

This rule should only occur once in the top level build file.
Running

.. code::
  
  bazel run //:gazelle

will cause gazelle to run with the supplied options in the source tree at the root.
See the `gazelle documentation`_ for more details.

+-----------------+-------------------+------------------------------------------------------------------------------------+
| Name            | Type              | Default value                                                                      |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **command**     | *string*          | ``update``                                                                         |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Controls the basic mode of operation gazelle runs in.                                                                    |
|                                                                                                                          |
| * ``update`` : Gazelle will create new BUILD files or update existing BUILD files if needed.                             |
| * ``fix`` : In addition to the changes made in update, Gazelle will make potentially breaking changes.                   |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **mode**        | *string*          | ``fix``                                                                            |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Controls the action gazelle takes when it detects files that are out of date.                                            |
|                                                                                                                          |
| * ``print`` : prints all of the updated BUILD files.                                                                     |
| * ``fix`` : rewrites all of the BUILD files in place.                                                                    |
| * ``diff`` : computes the rewrite but then just does a diff.                                                             |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **external**    | *string*          | ``external``                                                                       |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Controls how gazelle resolves import paths to labels.                                                                    |
|                                                                                                                          |
| * ``external`` : resolve external packages with go_repository_                                                           |
| * ``vendored`` : resolve external packages as packages in vendor                                                         |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **build_tags**  | *string_list*     | ``None``                                                                           |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| A list of build tags. If not specified, Gazelle will not filter sources with build constraints.                          |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **args**        | *string_list*     | ``None``                                                                           |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Arguments to forward to gazelle.                                                                                         |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **prefix**      | *string*          | ``""``                                                                             |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| The prefix of the target workspace. This is path fragement fom the GOPATH to your repository if it were checked out with |
| the normal go tools. It is combined the workspace relative path when guessing the import path of a library.              |
+-----------------+-------------------+------------------------------------------------------------------------------------+

go_embed_data
-------------

go_embed_data generates a .go file that contains data from a file or a list of files.
It should be consumed in the srcs list of one of the `core go rules`_.

+-----------------+-------------------+------------------------------------------------------------------------------------+
| Name            | Type              | Default value                                                                      |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **out**         | *string*          | **mandatory value**                                                                |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| File name of the .go file to generate.                                                                                   |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **package**     | *string*          | ``""``                                                                             |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Go package name for the generated .go file.                                                                              |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **var**         | *string*          | ``"Data"``                                                                         |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| Name of the variable that will contain the embedded data.                                                                |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **src**         | *string*          | ``""``                                                                             |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| A single file to embed. This cannot be used at the same time as **srcs**.                                                |
| The generated file will have a variable of type *[]byte* or *string* with the contents of this file.                     |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **srcs**        | *string*          | ``None``                                                                           |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| A list of files to embed. This cannot be used at the same time as **src**. The generated file will have a variable of    |
| type *map[string][]byte* or *map[string]string* with the contents of each file. The map keys are relative paths the      |
| files from the repository root. Keys for files in external repositories will be prefixed with ``"external/repo/"``       |
| where "repo" is the name of the external repository.                                                                     |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **flatten**     | *boolean*         | ``false``                                                                          |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| If ``true`` and **srcs** is used, map keys are file base names instead of relative paths.                                |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| **string**      | *boolean*         | ``false``                                                                          |
+-----------------+-------------------+------------------------------------------------------------------------------------+
| If ``true``, the embedded data will be stored as *string* instead of *[]byte*.                                           |
+-----------------+-------------------+------------------------------------------------------------------------------------+
        
       
