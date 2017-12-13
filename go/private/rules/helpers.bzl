# Copyright 2017 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_go//go/private:common.bzl",
    "go_importpath",
    "sets",
)
load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoSource",
    "GoArchive",
    "GoAspectProviders",
)

def new_go_library(ctx, resolver=None, importable=True, **kwargs):
  inferredpath = go_importpath(ctx)
  return GoLibrary(
      name = ctx.label.name,
      label = ctx.label,
      importpath = inferredpath if importable else None, # The canonical import path for this library
      exportpath = inferredpath, # The export source path for this library
      resolve = resolver,
      **kwargs
  )

def new_aspect_provider(source = None, archive = None):
  return GoAspectProviders(
      source = source,
      archive = archive,
  )

def get_source(dep):
  if GoAspectProviders in dep:
    return dep[GoAspectProviders].source
  return dep[GoSource]

def get_archive(dep):
  if GoAspectProviders in dep:
    return dep[GoAspectProviders].archive
  return dep[GoArchive]

def merge_embed(source, embed):
  s = get_source(embed)
  source["srcs"] = s.srcs + source["srcs"]
  source["cover"] = source["cover"] + s.cover
  source["deps"] = source["deps"] + s.deps
  source["gc_goopts"] = source["gc_goopts"] + s.gc_goopts
  source["runfiles"] = source["runfiles"].merge(s.runfiles)
  source["cgo_deps"] = source["cgo_deps"] + s.cgo_deps
  source["cgo_exports"] = source["cgo_exports"] + s.cgo_exports
  if s.cgo_archive:
    if source["cgo_archive"]:
      fail("multiple libraries with cgo_archive embedded")
    source["cgo_archive"] = s.cgo_archive

def library_to_source(ctx, attr, library, mode):
  attr_srcs = [f for t in getattr(attr, "srcs", []) for f in t.files]
  generated_srcs = getattr(library, "srcs", [])
  source = {
      "library" : library,
      "mode" : mode,
      "srcs" : generated_srcs + attr_srcs,
      "cover" : [],
      "deps" : getattr(attr, "deps", []),
      "gc_goopts" : getattr(attr, "gc_goopts", []),
      "runfiles" : ctx.runfiles(collect_data = True),
      "cgo_archive" : None,
      "cgo_deps" : [],
      "cgo_exports" : [],
  }
  if ctx.coverage_instrumented() and not attr.testonly:
    source["cover"] = attr_srcs
  for e in getattr(attr, "embed", []):
    merge_embed(source, e)
  if library.resolve:
    library.resolve(ctx, attr, source)
  return GoSource(**source)

