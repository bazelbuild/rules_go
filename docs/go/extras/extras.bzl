"""
  [gazelle rule]: https://github.com/bazelbuild/bazel-gazelle#bazel-rule
  [uber-go/mock]: https://github.com/uber-go/mock
  [core go rules]: /docs/go/core/rules.md

# Extra rules

This is a collection of helper rules. These are not core to building a go binary, but are supplied
to make life a little easier.

## Contents
- [gazelle](#gazelle)
- [gomock](#gomock)

## Additional resources
- [gazelle rule]
- [uber-go/mock]
- [core go rules]

------------------------------------------------------------------------

gazelle
-------

This rule has moved. See [gazelle rule] in the Gazelle repository.

"""

load("//extras:gomock.bzl", _gomock = "gomock")

gomock = _gomock
