"""
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

"""

load("//extras:gomock.bzl", _gomock = "gomock")
load("//extras:embed_data.bzl", _go_embed_data = "go_embed_data")

gomock = _gomock

go_embed_data = _go_embed_data
