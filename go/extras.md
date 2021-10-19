Extra rules
===========

.. _`core go rules`: core.rst
.. _go_repository: https://github.com/bazelbuild/bazel-gazelle/blob/master/repository.rst#go_repository
.. _`gazelle documentation`: https://github.com/bazelbuild/bazel-gazelle/blob/master/README.rst
.. _gazelle rule: https://github.com/bazelbuild/bazel-gazelle#bazel-rule
.. _gomock_rule: https://github.com/jmhodges/bazel_gomock
.. _golang/mock: https://github.com/golang/mock

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

This is a collection of helper rules. These are not core to building a go binary, but are supplied
to make life a little easier.

gazelle
-------

This rule has moved. See `gazelle rule`_ in the Gazelle repository.

gomock
------

This rule allows you to generate mock interfaces with mockgen (from `golang/mock`_) which can be useful for certain testing scenarios. See  `gomock_rule`_ in the gomock repository.


<a id="#go_embed_data"></a>

## go_embed_data

<pre>
go_embed_data(<a href="#go_embed_data-name">name</a>, <a href="#go_embed_data-flatten">flatten</a>, <a href="#go_embed_data-package">package</a>, <a href="#go_embed_data-src">src</a>, <a href="#go_embed_data-srcs">srcs</a>, <a href="#go_embed_data-string">string</a>, <a href="#go_embed_data-unpack">unpack</a>, <a href="#go_embed_data-var">var</a>)
</pre>

``go_embed_data`` generates a .go file that contains data from a file or a
list of files. It should be consumed in the srcs list of one of the
`core go rules`_.

Before using ``go_embed_data``, you must add the following snippet to your
WORKSPACE:

.. code:: bzl

    load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

    go_embed_data_dependencies()


``go_embed_data`` accepts the attributes listed below.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="go_embed_data-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="go_embed_data-flatten"></a>flatten |  -   | Boolean | optional | False |
| <a id="go_embed_data-package"></a>package |  -   | String | optional | "" |
| <a id="go_embed_data-src"></a>src |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="go_embed_data-srcs"></a>srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="go_embed_data-string"></a>string |  -   | Boolean | optional | False |
| <a id="go_embed_data-unpack"></a>unpack |  -   | Boolean | optional | False |
| <a id="go_embed_data-var"></a>var |  Name of the variable that will contain the embedded data.   | String | optional | "Data" |


