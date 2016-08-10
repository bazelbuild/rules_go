# Using external libraries with Go and Bazel

To depend on external libraries, you have two options: vendoring or external
repositories.

## Vendoring

The first option is to _vendor_ the libraries - that is, copy them all into a "vendor"
subdirectory inside your own library, and create your own BUILD files for each
vendor repository. Vendoring is a part of Go since 1.5 - see https://golang.org/s/go15vendor
for more details, and note that vendoring is enabled by default since Go 1.6.

Take care to observe the following restrictions while using vendoring:
  * You cannot use `git submodule` since you'll need to be adding the
    BUILD files at every level of the hierarchy.
  * Since the Bazel rules do not currently support build constraints,
    you'll need to manually include/exclude files with tags such as
    `//+build !go1.5`.

Vendoring may be preferable to using external repositories (see below) if
you have different packages that require different versions of external
repos.

## WORKSPACE repositories

The other option to use external libraries is to use one of the `repository`
directives in your WORKSPACE file. This is initially no faster or easier than
vendoring the libraries, since you still need to create a BUILD file for every
external package, including subpackages. However, because the BUILD files are
separate from the source tree (and can even be embedded inside the WORKSPACE
file using the `build_file_content` attribute of the `new_git_repository` command,
it is easier to support upgraded versions of external libraries.

## General rules

In either case, you must follow these rules for your BUILD files (or build file
contents) for external libraries:
  * Import the Bazel go rules - you don't get them "for free."
  * Declare a `go_prefix`, almost certainly matching the name of the repository
    you're cloning.
  * Declare a single `go_library` named `go_default_library` in each BUILD
    file, assuming that each directory contains a single Go package. You can't
    use a single BUILD file to define subpackages, for example.
  * Have public visibility (see example below)
  * Exclude any `*test.go` files from the `go_library` srcs. Normally Go would
    do this for you, but the `go_library` rule does not.
  * Manually exclude files with build tags that wouldn't be satisfied - for
    example, if a file includes the build constraint `//+build !go1.5` and
    you're using a Go 1.5 or later, you must exclude this file yourself.

If you're using external repositories, each repo can only define a
*single* BUILD file (or build file contents). This implies that if you're
importing mulitple libraries from the same repo, you'll need to import
that repo multiple times, and _not_ simply define multiple targets in the
single BUILD file/variable.

## Example

Here is an example from a WORKSPACE file using the repository method for
`github.com/golang/glog`. If you were vendoring this library, you'd simply use
the contents of the GLOG_BUILD variable as your BUILD file.

```bzl
GLOG_BUILD = """
load("@io_bazel_rules_go//go:def.bzl", "go_prefix", "go_library")
go_prefix("github.com/golang/glog")
go_library(
  name = "go_default_library",
  srcs = glob(["*.go"]),
  visibility = ["//visibility:public"],
)
"""

new_git_repository(
  # In other BUILD files, we'll refer to this library as
  # @golang_glog//:go_default_library
  name = "golang_glog",
  build_file_content = GLOG_BUILD,
  commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
  remote = "https://github.com/golang/glog",
)
```
