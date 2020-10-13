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

load(
    "//go/private/rules:library.bzl",
    "go_library",
)
load(
    "//go/private/rules:binary.bzl",
    "go_binary",
    "go_transition_binary",
)
load(
    "//go/private/rules:test.bzl",
    "go_test",
    "go_transition_test",
)
load(
    "//go/private/rules:cgo.bzl",
    "go_binary_c_archive_shared",
)
load(
    "//go/private/rules:transition.bzl",
    "go_transition_wrapper",
)

def _cgo(name, kwargs):
    if "objc" in kwargs:
        fail("//{}:{}: the objc attribute has been removed. .m sources may be included in srcs or may be extracted into a separated objc_library listed in cdeps.".format(native.package_name(), name))

def go_library_macro(name, **kwargs):
    """See go/core.rst#go_library for full documentation."""
    _cgo(name, kwargs)
    go_library(name = name, **kwargs)

def go_binary_macro(name, **kwargs):
    """See go/core.rst#go_binary for full documentation."""
    _cgo(name, kwargs)
    go_transition_wrapper(go_binary, go_transition_binary, name = name, **kwargs)
    go_binary_c_archive_shared(name, kwargs)

def go_test_macro(name, **kwargs):
    """See go/core.rst#go_test for full documentation."""
    _cgo(name, kwargs)
    go_transition_wrapper(go_test, go_transition_test, name = name, **kwargs)
