<!-- Generated with Stardoc: http://skydoc.bazel.build -->


  [gazelle rule]: https://github.com/bazelbuild/bazel-gazelle#bazel-rule
  [golang/mock]: https://github.com/golang/mock
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
- [core go rules]

------------------------------------------------------------------------

gazelle
-------

This rule has moved. See [gazelle rule] in the Gazelle repository.






<a id="#go_embed_data"></a>

## go_embed_data

<pre>
go_embed_data(<a href="#go_embed_data-name">name</a>, <a href="#go_embed_data-flatten">flatten</a>, <a href="#go_embed_data-package">package</a>, <a href="#go_embed_data-src">src</a>, <a href="#go_embed_data-srcs">srcs</a>, <a href="#go_embed_data-string">string</a>, <a href="#go_embed_data-unpack">unpack</a>, <a href="#go_embed_data-var">var</a>)
</pre>

**Deprecated**: Will be removed in rules_go 0.39.

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
| <a id="go_embed_data-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="go_embed_data-flatten"></a>flatten |  If <code>True</code> and <code>srcs</code> is used, map keys are file base names instead of relative paths.   | Boolean | optional | False |
| <a id="go_embed_data-package"></a>package |  Go package name for the generated .go file.   | String | optional | "" |
| <a id="go_embed_data-src"></a>src |  A single file to embed. This cannot be used at the same time as <code>srcs</code>.             The generated file will have a variable of type <code>[]byte</code> or <code>string</code> with the contents of this file.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | None |
| <a id="go_embed_data-srcs"></a>srcs |  A list of files to embed. This cannot be used at the same time as <code>src</code>.             The generated file will have a variable of type <code>map[string][]byte</code> or <code>map[string]string</code> with the contents             of each file. The map keys are relative paths of the files from the repository root. Keys for files in external             repositories will be prefixed with <code>"external/repo/"</code> where "repo" is the name of the external repository.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | [] |
| <a id="go_embed_data-string"></a>string |  If <code>True</code>, the embedded data will be stored as <code>string</code> instead of <code>[]byte</code>.   | Boolean | optional | False |
| <a id="go_embed_data-unpack"></a>unpack |  If <code>True</code>, sources are treated as archives and their contents will be stored. Supported formats are <code>.zip</code> and <code>.tar</code>   | Boolean | optional | False |
| <a id="go_embed_data-var"></a>var |  Name of the variable that will contain the embedded data.   | String | optional | "Data" |


<a id="gomock"></a>

## gomock

<pre>
gomock(<a href="#gomock-name">name</a>, <a href="#gomock-library">library</a>, <a href="#gomock-out">out</a>, <a href="#gomock-source">source</a>, <a href="#gomock-interfaces">interfaces</a>, <a href="#gomock-package">package</a>, <a href="#gomock-self_package">self_package</a>, <a href="#gomock-aux_files">aux_files</a>, <a href="#gomock-mockgen_tool">mockgen_tool</a>,
       <a href="#gomock-imports">imports</a>, <a href="#gomock-copyright_file">copyright_file</a>, <a href="#gomock-mock_names">mock_names</a>, <a href="#gomock-kwargs">kwargs</a>)
</pre>

Calls [mockgen](https://github.com/golang/mock) to generates a Go file containing mocks from the given library.

If `source` is given, the mocks are generated in source mode; otherwise in reflective mode.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="gomock-name"></a>name |  the target name.   |  none |
| <a id="gomock-library"></a>library |  the Go library to took for the interfaces (reflecitve mode) or source (source mode).   |  none |
| <a id="gomock-out"></a>out |  the output Go file name.   |  none |
| <a id="gomock-source"></a>source |  a Go file in the given <code>library</code>. If this is given, <code>gomock</code> will call mockgen in source mode to mock all interfaces in the file.   |  <code>None</code> |
| <a id="gomock-interfaces"></a>interfaces |  a list of interfaces in the given <code>library</code> to be mocked in reflective mode.   |  <code>[]</code> |
| <a id="gomock-package"></a>package |  the name of the package the generated mocks should be in. If not specified, uses mockgen's default. See [mockgen's -package](https://github.com/golang/mock#flags) for more information.   |  <code>""</code> |
| <a id="gomock-self_package"></a>self_package |  the full package import path for the generated code. The purpose of this flag is to prevent import cycles in the generated code by trying to include its own package. See [mockgen's -self_package](https://github.com/golang/mock#flags) for more information.   |  <code>""</code> |
| <a id="gomock-aux_files"></a>aux_files |  a map from source files to their package path. This only needed when <code>source</code> is provided. See [mockgen's -aux_files](https://github.com/golang/mock#flags) for more information.   |  <code>{}</code> |
| <a id="gomock-mockgen_tool"></a>mockgen_tool |  the mockgen tool to run.   |  <code>Label("//extras/gomock:mockgen")</code> |
| <a id="gomock-imports"></a>imports |  dictionary of name-path pairs of explicit imports to use. See [mockgen's -imports](https://github.com/golang/mock#flags) for more information.   |  <code>{}</code> |
| <a id="gomock-copyright_file"></a>copyright_file |  optional file containing copyright to prepend to the generated contents. See [mockgen's -copyright_file](https://github.com/golang/mock#flags) for more information.   |  <code>None</code> |
| <a id="gomock-mock_names"></a>mock_names |  dictionary of interface name to mock name pairs to change the output names of the mock objects. Mock names default to 'Mock' prepended to the name of the interface. See [mockgen's -mock_names](https://github.com/golang/mock#flags) for more information.   |  <code>{}</code> |
| <a id="gomock-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


