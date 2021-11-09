<!-- Generated with Stardoc: http://skydoc.bazel.build -->


  [gazelle rule]: https://github.com/bazelbuild/bazel-gazelle#bazel-rule
  [golang/mock]: https://github.com/golang/mock
  [gomock_rule]: https://github.com/jmhodges/bazel_gomock
  [core go rules]: /docs/go/core/rules.md

# Extra rules

This is a collection of helper rules. These are not core to building a go binary, but are supplied
to make life a little easier.

## Contents
- [gazelle](#gazelle)
- [gomock](#gomock)
- [go_embed_data](#go_embed_data)

## Additional resources
- [gazelle rule]
- [golang/mock]
- [gomock_rule]
- [core go rules]

------------------------------------------------------------------------

gazelle
-------

This rule has moved. See [gazelle rule] in the Gazelle repository.

gomock
------

This rule allows you to generate mock interfaces with mockgen (from [golang/mock]) which can be useful for certain testing scenarios. See [gomock_rule] in the gomock repository.





<a id="#go_embed_data"></a>

## go_embed_data

<pre>
go_embed_data(<a href="#go_embed_data-name">name</a>, <a href="#go_embed_data-flatten">flatten</a>, <a href="#go_embed_data-package">package</a>, <a href="#go_embed_data-src">src</a>, <a href="#go_embed_data-srcs">srcs</a>, <a href="#go_embed_data-string">string</a>, <a href="#go_embed_data-unpack">unpack</a>, <a href="#go_embed_data-var">var</a>)
</pre>

`go_embed_data` generates a .go file that contains data from a file or a
list of files. It should be consumed in the srcs list of one of the
[core go rules].

Before using `go_embed_data`, you must add the following snippet to your
WORKSPACE:

``` bzl
load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

go_embed_data_dependencies()
```

`go_embed_data` accepts the attributes listed below.


### **Attributes**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="go_embed_data-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="go_embed_data-flatten"></a>flatten |  If <code>True</code> and <code>srcs</code> is used, map keys are file base names instead of relative paths.   | Boolean | optional | False |
| <a id="go_embed_data-package"></a>package |  Go package name for the generated .go file.   | String | optional | "" |
| <a id="go_embed_data-src"></a>src |  A single file to embed. This cannot be used at the same time as <code>srcs</code>.             The generated file will have a variable of type <code>[]byte</code> or <code>string</code> with the contents of this file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="go_embed_data-srcs"></a>srcs |  A list of files to embed. This cannot be used at the same time as <code>src</code>.             The generated file will have a variable of type <code>map[string][]byte</code> or <code>map[string]string</code> with the contents             of each file. The map keys are relative paths of the files from the repository root. Keys for files in external             repositories will be prefixed with <code>"external/repo/"</code> where "repo" is the name of the external repository.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="go_embed_data-string"></a>string |  If <code>True</code>, the embedded data will be stored as <code>string</code> instead of <code>[]byte</code>.   | Boolean | optional | False |
| <a id="go_embed_data-unpack"></a>unpack |  If <code>True</code>, sources are treated as archives and their contents will be stored. Supported formats are <code>.zip</code> and <code>.tar</code>   | Boolean | optional | False |
| <a id="go_embed_data-var"></a>var |  Name of the variable that will contain the embedded data.   | String | optional | "Data" |


