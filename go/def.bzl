# Copyright 2014 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@io_bazel_rules_go//go/private:providers.bzl",
    _GoSource = "GoSource",
    _GoLibrary = "GoLibrary",
    _GoBinary = "GoBinary",
)
load("@io_bazel_rules_go//go/private:repositories.bzl", "go_repositories")
load("@io_bazel_rules_go//go/private:go_repository.bzl", "go_repository", "new_go_repository")
load("@io_bazel_rules_go//go/private:go_prefix.bzl", "go_prefix")
load("@io_bazel_rules_go//go/private:cgo.bzl", "cgo_library", "cgo_genrule")
load("@io_bazel_rules_go//go/private:gazelle.bzl", "gazelle")
load("@io_bazel_rules_go//go/private:wrappers.bzl",
    _go_library_macro = "go_library_macro",
    _go_binary_macro = "go_binary_macro",
    _go_test_macro = "go_test_macro",
)

GoSource = _GoSource
"""
This is the provider used to expose a go sources to other rules.
It provides the following fields:
  TODO: List all the provider fields here
"""

GoLibrary = _GoLibrary
"""
This is the provider used to expose a go library to other rules.
It provides the following fields:
  TODO: List all the provider fields here
"""

GoBinary = _GoBinary
"""
This is the provider used to expose a go binary to other rules.
It provides the following fields:
  TODO: List all the provider fields here
"""

go_library = _go_library_macro
"""
    go_library is a macro for building go libraries.
    It returns the GoSource and GoLibrary providers,
    and accepts the following attributes:
        "importpath": attr.string(),
        # inputs
        "srcs": attr.label_list(),
        "deps": attr.label_list(),
        "data": attr.label_list(allow_files = True, cfg = "data"),
        # compile options
        "gc_goopts": attr.string_list(), # Options for the go compiler if using gc
        "gccgo_goopts": attr.string_list(), # Options for the go compiler if using gcc
        # cgo options
        "cgo": attr.bool(),
        "cdeps": attr.label_list(), # TODO: Would be nicer to be able to filter deps instead
        "copts": attr.string_list(), # Options for the the c compiler
        "clinkopts": attr.string_list(), # Options for the linker
"""

go_binary = _go_binary_macro
"""
    go_library is a macro for building go executables.
    It returns the GoLibrary and GoBinary providers,
    and accepts the following attributes:
        "importpath": attr.string(),
        # inputs
        "srcs": attr.label_list(),
        "deps": attr.label_list(),
        "data": attr.label_list(allow_files = True, cfg = "data"),
        # compile options
        "gc_goopts": attr.string_list(), # Options for the go compiler if using gc
        "gccgo_goopts": attr.string_list(), # Options for the go compiler if using gcc
        # link options
        "gc_linkopts": attr.string_list(), # Options for the go linker if using gc
        "gccgo_linkopts": attr.string_list(), # Options for the go linker if using gcc
        "stamp": attr.int(),
        "linkstamp": attr.string(),
        "x_defs": attr.string_dict(),
        # cgo options
        "cgo": attr.bool(),
        "cdeps": attr.label_list(), # TODO: Would be nicer to be able to filter deps instead
        "copts": attr.string_list(), # Options for the the c compiler
        "clinkopts": attr.string_list(), # Options for the linker
"""

go_test = _go_test_macro
"""
    go_test is a macro for building go executable tests.
    It returns the GoLibrary and GoBinary providers,
    and accepts the following attributes:
        "importpath": attr.string(),
        "defines_main": attr.bool(),
        # inputs
        "srcs": attr.label_list(),
        "deps": attr.label_list(),
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "library": attr.label(),
        # compile options
        "gc_goopts": attr.string_list(), # Options for the go compiler if using gc
        "gccgo_goopts": attr.string_list(), # Options for the go compiler if using gcc
        # link options
        "gc_linkopts": attr.string_list(), # Options for the go linker if using gc
        "gccgo_linkopts": attr.string_list(), # Options for the go linker if using gcc
        "stamp": attr.int(),
        "linkstamp": attr.string(),
        "x_defs": attr.string_dict(),
        # cgo options
        "cgo": attr.bool(),
        "cdeps": attr.label_list(), # TODO: Would be nicer to be able to filter deps instead
        "copts": attr.string_list(), # Options for the the c compiler
        "clinkopts": attr.string_list(), # Options for the linker
"""
