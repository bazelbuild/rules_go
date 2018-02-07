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
"""
A represenatation of the inputs to a go package.
This is a configuration independent provider.
You must call resolve with a mode to produce a GoSource.
See go/providers.rst#GoLibrary for full documentation.
"""

GoSource = provider()
"""
The filtered inputs and dependencies needed to build a GoArchive
This is a configuration specific provider.
It has no transitive information.
See go/providers.rst#GoSource for full documentation.
"""

GoArchiveData = provider()
"""
This compiled form of a package used in transitive dependencies.
This is a configuration specific provider.
See go/providers.rst#GoArchiveData for full documentation.
"""

GoArchive = provider()
"""
The compiled form of a GoLibrary, with everything needed to link it into a binary.
This is a configuration specific provider.
See go/providers.rst#GoArchive for full documentation.
"""

GoAspectProviders = provider()

GoPath = provider()

GoStdLib = provider()

GoBuilders = provider()

def new_aspect_provider(source = None, archive = None):
  return GoAspectProviders(
      source = source,
      archive = archive,
  )

def get_source(dep):
  if type(dep) == "struct":
    return dep
  if GoAspectProviders in dep:
    return dep[GoAspectProviders].source
  return dep[GoSource]

def get_archive(dep):
  if type(dep) == "struct":
    return dep
  if GoAspectProviders in dep:
    return dep[GoAspectProviders].archive
  return dep[GoArchive]
