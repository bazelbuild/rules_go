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

load("@io_bazel_rules_go//go/private:rules/binary.bzl", "go_binary")
load("@io_bazel_rules_go//go/private:rules/library.bzl", "go_library")
load("@io_bazel_rules_go//go/private:rules/test.bzl", "go_test")
load(
    "@io_bazel_rules_go//go/private:rules/cgo.bzl",
    "setup_cgo_library",
    "go_binary_c_archive_shared",
)

_CGO_ATTRS = {
    "srcs": None,
    "cdeps": [],
    "copts": [],
    "cxxopts": [],
    "cppopts": [],
    "clinkopts": [],
    "objc": False,
}

_OBJC_CGO_ATTRS = {
    "hdrs": None,
    "defines": None,
    "enable_modules": None,
    "includes": None,
    "module_map": None,
    "non_arc_srcs": None,
    "pch": None,
    "sdk_dylibs": None,
    "sdk_frameworks": None,
    "sdk_includes": None,
    "textual_hdrs": None,
    "weak_sdk_frameworks": None,
}

_COMMON_ATTRS = {
    "tags": None,
    "restricted_to": None,
    "compatible_with": None,
}

def _deprecate(attr, name, ruletype, kwargs, message):
  value = kwargs.pop(attr, None)
  if value and native.repository_name() == "@":
    print("\nDEPRECATED: //{}:{} : the {} attribute on {} is deprecated. {}".format(native.package_name(), name, attr, ruletype, message))
  return value

def _objc(name, kwargs):
  objcopts = {}
  for key in kwargs.keys():
    if key.startswith("objc_"):
      arg = key[len("objc_"):]
      if arg not in _OBJC_CGO_ATTRS:
        fail("Forbidden CGo objc_library parameter: " + arg)
      value = kwargs.pop(key)
      objcopts[arg] = value
  return objcopts

def _cgo(name, kwargs):
  cgo = kwargs.pop("cgo", False)
  if not cgo: return
  cgo_attrs = {"name":name}
  for key, default in _CGO_ATTRS.items():
    cgo_attrs[key] = kwargs.pop(key, default)
  for key, default in _COMMON_ATTRS.items():
    cgo_attrs[key] = kwargs.get(key, default)
  cgo_attrs["objcopts"] = _objc(name, kwargs)
  cgo_embed = setup_cgo_library(**cgo_attrs)
  kwargs["embed"] = kwargs.get("embed", []) + [cgo_embed]

def go_library_macro(name, **kwargs):
  """See go/core.rst#go_library for full documentation."""
  _cgo(name, kwargs)
  go_library(name = name, **kwargs)

def go_binary_macro(name, **kwargs):
  """See go/core.rst#go_binary for full documentation."""
  _cgo(name, kwargs)
  go_binary(name = name, **kwargs)
  go_binary_c_archive_shared(name, kwargs)

def go_test_macro(name, **kwargs):
  """See go/core.rst#go_test for full documentation."""
  _cgo(name, kwargs)
  go_test(name = name, **kwargs)
