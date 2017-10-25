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

load("@io_bazel_rules_go//go/private:mode.bzl", "mode_string")

GoLibrary = provider()
"""See go/providers.rst#GoLibrary for full documentation."""

GoBinary = provider()
"""See go/providers.rst#GoBinary for full documentation."""

GoPath = provider()

GoEmbed = provider()
"""See go/providers.rst#GoEmbed for full documentation."""

CgoInfo = provider()
GoStdLib = provider()

def library_attr(mode):
  """Returns the attribute name for the library of the given mode.

  mode must a struct returned by common.bzl#mode
  """
  return mode_string(mode)+"_library"

def get_library(golib, mode):
  """Returns the compiled library for the given mode

  golib must be a GoLibrary
  mode must a struct returned by common.bzl#mode
  """
  return getattr(golib, library_attr(mode))

def searchpath_attr(mode):
  """Returns the search path for the given mode

  mode must a struct returned by common.bzl#mode
  """
  return mode_string(mode)+"_searchpath"

def get_searchpath(golib, mode):
  """Returns the search path for the given mode

  golib must be a GoLibrary
  mode must a struct returned by common.bzl#mode
  """
  return getattr(golib, searchpath_attr(mode))


