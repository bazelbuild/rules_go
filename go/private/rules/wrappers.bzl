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
load("@io_bazel_rules_go//go/private:rules/cgo.bzl", "setup_cgo_library")

def go_library_macro(name, srcs=None, cgo=False, cdeps=[], copts=[], clinkopts=[], **kwargs):
  """See go/core.rst#go_library for full documentation."""
  cgo_info = None
  if cgo:
    cgo_info = setup_cgo_library(
        name = name,
        srcs = srcs,
        cdeps = cdeps,
        copts = copts,
        clinkopts = clinkopts,
    )
  go_library(
      name = name,
      srcs = srcs,
      cgo_info = cgo_info,
      **kwargs
  )

def go_binary_macro(name, srcs=None, cgo=False, cdeps=[], copts=[], clinkopts=[], **kwargs):
  """See go/core.rst#go_binary for full documentation."""
  cgo_info = None
  if cgo:
    cgo_info = setup_cgo_library(
        name = name,
        srcs = srcs,
        cdeps = cdeps,
        copts = copts,
        clinkopts = clinkopts,
    )
  return go_binary(
      name = name,
      srcs = srcs,
      cgo_info = cgo_info,
      **kwargs
  )

def go_test_macro(name, srcs=None, deps=None, importpath="", library=None, embed=[], gc_goopts=[], cgo=False, cdeps=[], copts=[], clinkopts=[], **kwargs):
  """See go/core.rst#go_test for full documentation."""
  library_name = name + "~library~"
  go_library_macro(
      name = library_name,
      visibility = ["//visibility:private"],
      srcs = srcs,
      deps = deps,
      importpath = importpath,
      library = library,
      embed = embed,
      gc_goopts = gc_goopts,
      testonly = True,
      tags = ["manual"],
      cgo = False, 
      cdeps = cdeps,
      copts = copts,
      clinkopts = clinkopts,
  )
  return go_test(
      name = name,
      library = library_name,
      gc_goopts = gc_goopts,
      **kwargs
  )
