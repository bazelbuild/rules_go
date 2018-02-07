# Using external libraries with Go and Bazel

To depend on external libraries, you have two options: vendoring or external
repositories.

## Vendoring

The first option is to _vendor_ the libraries - that is, copy them all into a
"vendor" subdirectory inside your own library, and create your own BUILD files
for each vendor repository. Vendoring is a part of Go since 1.5 - see
https://golang.org/s/go15vendor for more details, and note that vendoring is
enabled by default since Go 1.6.

Take care to observe the following restrictions while using vendoring:
  * You cannot use `git submodule` since you'll need to be adding the
    BUILD files at every level of the hierarchy.
  * Since the Bazel rules do not currently support build constraints,
    you'll need to manually include/exclude files with tags such as
    `//+build !go1.5`.

Vendoring may be preferable to using external repositories (see below) if
you have different packages that require different versions of external
repos.

## `WORKSPACE` repositories

The other option for using external libraries is to import them in your
`WORKSPACE` file. You can use
the [`go_repository`](go/workspace.rst#go_repository) rule to import
repositories that conform to the normal Go directory conventions. This is
similar to `new_git_repository`, but it automatically generates `BUILD` files
for you using [gazelle](https://github.com/bazelbuild/bazel-gazelle).

You can use [`go_repository`](go/workspace.rst#go_repository) if the project
you're importing already has `BUILD` files. This is like `git_repository` but it
recognizes importpath redirection. You can use
[`gazelle update-repos`](https://github.com/bazelbuild/bazel-gazelle#update-repos)
to add, update, and import repository rules.

If you prefer to write your own `BUILD` files for dependencies, you can still
use `new_git_repository`. Be aware that you can only specify one `BUILD` file
for the top-level package.

### Example

Here is an example from a `WORKSPACE` file using the repository method for
`github.com/golang/glog`.

``` bzl
# Import Go rules and toolchain.
git_repository(
    name = "io_bazel_rules_go",
    remote = "https://github.com/bazelbuild/rules_go.git",
    tag = "0.4.1",
)
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

# Import Go dependencies.
go_repository(
    name = "com_github_golang_glog",
    importpath = "github.com/golang/glog",
    commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
)
```

You could use this library in the `deps` of a `go_library` with the label
`@com_github_golang_glog//:go_default_library`. If you were vendoring this
library, you'd refer to it as
`//vendor/github.com/golang/glog:go_default_library` instead.

## General rules

If you write your own `BUILD` files for dependencies, whether they are vendored
or imported through `WORKSPACE`, here are some things to keep in mind.

* Don't forget to load the Bazel rules from this repository (`go_library`,
  etc). You don't get them for free.
* Declare a [`go_prefix`](README.md#go_prefix), almost certainly matching the
  import path of the repository you're cloning.
* Declare a single [`go_library`](README.md#go_library) named
  `go_default_library` in each `BUILD` file, assuming that each directory
  contains a single Go package. You can't use a single `BUILD` file to define
  subpackages, for example.
* Have public visibility.
* Exclude any `*_test.go` files from the `go_library` srcs. Unlike the `go`
  tool, `go_library` does not do this automatically.
* Manually exclude files with build tags that wouldn't be satisfied - for
  example, if a file includes the build constraint `//+build !go1.5` and
  you're using a Go 1.5 or later, you must exclude this file yourself.

### Example

``` bzl
load("@io_bazel_rules_go//go:def.bzl", "go_prefix", "go_library")

go_prefix("github.com/golang/glog")

go_library(
    name = "go_default_library",
    srcs = glob(["*.go"], exclude=["*_test.go"]),
    visibility = ["//visibility:public"],
)
```
