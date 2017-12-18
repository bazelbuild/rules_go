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

load("@io_bazel_rules_go//go/private:providers.bzl",
    "GoLibrary",
    "GoSource",
    "GoAspectProviders",
    "GoStdLib",
    "get_source",
)
load("@io_bazel_rules_go//go/platform:list.bzl",
    "GOOS_GOARCH",
)
load("@io_bazel_rules_go//go/private:mode.bzl",
    "get_mode",
    "mode_string",
)
load("@io_bazel_rules_go//go/private:common.bzl",
    "structs",
    "goos_to_extension",
)

GoContext = provider()

def _declare_file(go, path="", ext="", name = ""):
  filename = mode_string(go.mode) + "/"
  filename += name if name else go._ctx.label.name
  if path:
    filename += "~/" + path
  if ext:
    filename += ext
  return go.actions.declare_file(filename)

def _new_args(go):
  args = go.actions.args()
  args.add([
      "-go", go.stdlib.go,
      "-root_file", go.stdlib.root_file,
      "-goos", go.mode.goos,
      "-goarch", go.mode.goarch,
      "-cgo=" + ("0" if go.mode.pure else "1"),
  ])
  return args

def _new_library(go, resolver=None, importable=True, **kwargs):
  return GoLibrary(
      name = go._ctx.label.name,
      label = go._ctx.label,
      importpath = go._inferredpath if importable else None, # The canonical import path for this library
      exportpath = go._inferredpath, # The export source path for this library
      resolve = resolver,
      **kwargs
  )

def _merge_embed(source, embed):
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

def _library_to_source(go, attr, library, coverage_instrumented):
  attr_srcs = [f for t in getattr(attr, "srcs", []) for f in t.files]
  generated_srcs = getattr(library, "srcs", [])
  source = {
      "library" : library,
      "mode" : go.mode,
      "srcs" : generated_srcs + attr_srcs,
      "cover" : [],
      "deps" : getattr(attr, "deps", []),
      "gc_goopts" : getattr(attr, "gc_goopts", []),
      "runfiles" : go._ctx.runfiles(collect_data = True),
      "cgo_archive" : None,
      "cgo_deps" : [],
      "cgo_exports" : [],
  }
  if coverage_instrumented and not attr.testonly:
    source["cover"] = attr_srcs
  for e in getattr(attr, "embed", []):
    _merge_embed(source, e)
  if library.resolve:
    library.resolve(go, attr, source, _merge_embed)
  return GoSource(**source)


def _infer_importpath(ctx):
  DEFAULT_LIB = "go_default_library"
  VENDOR_PREFIX = "/vendor/"
  path = getattr(ctx.attr, "importpath", None)
  if path != "":
    return path
  prefix = getattr(ctx.attr, "_go_prefix", None)
  path = prefix.go_prefix if prefix else ""
  if path.endswith("/"):
    path = path[:-1]
  if ctx.label.package:
    path += "/" + ctx.label.package
  if ctx.label.name != DEFAULT_LIB and not path.endswith(ctx.label.name):
    path += "/" + ctx.label.name
  if path.rfind(VENDOR_PREFIX) != -1:
    path = path[len(VENDOR_PREFIX) + path.rfind(VENDOR_PREFIX):]
  if path[0] == "/":
    path = path[1:]
  return path


def go_context(ctx, attr=None):
  if "@io_bazel_rules_go//go:toolchain" in ctx.toolchains:
    toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  elif "@io_bazel_rules_go//go:bootstrap_toolchain" in ctx.toolchains:
    toolchain = ctx.toolchains["@io_bazel_rules_go//go:bootstrap_toolchain"]
  else:
    fail('Rule {} does not have the go toolchain available\nAdd toolchains = ["@io_bazel_rules_go//go:toolchain"] to the rule definition.'.format(ctx.label))

  if not attr:
    attr = ctx.attr

  context_data = attr._go_context_data
  mode = get_mode(ctx, toolchain, context_data)

  stdlib = None
  for check in [s[GoStdLib] for s in context_data.stdlib_all]:
    if (check.goos == mode.goos and
        check.goarch == mode.goarch and
        check.race == mode.race and
        check.pure == mode.pure):
      if stdlib:
        fail("Multiple matching standard library for "+mode_string(mode))
      stdlib = check
  if not stdlib:
    fail("No matching standard library for "+mode_string(mode))

  return GoContext(
      # Fields
      toolchain = toolchain,
      mode = mode,
      stdlib = stdlib,
      actions = ctx.actions,
      exe_extension = goos_to_extension(mode.goos),
      crosstool = context_data.crosstool,
      package_list = context_data.package_list,
      # Action generators
      archive = toolchain.actions.archive,
      asm = toolchain.actions.asm,
      binary = toolchain.actions.binary,
      compile = toolchain.actions.compile,
      cover = toolchain.actions.cover if ctx.configuration.coverage_enabled else None,
      link = toolchain.actions.link,
      pack = toolchain.actions.pack,

      # Helpers
      args = _new_args,
      new_library = _new_library,
      library_to_source = _library_to_source,
      declare_file = _declare_file,

      # Private
      _ctx = ctx, # TODO: All uses of this should be removed
      _inferredpath = _infer_importpath(ctx), # TODO: remove when go_prefix goes away
  )

def _stdlib_all():
  stdlibs = []
  for goos, goarch in GOOS_GOARCH:
    stdlibs.extend([
      Label("@go_stdlib_{}_{}_cgo".format(goos, goarch)),
      Label("@go_stdlib_{}_{}_pure".format(goos, goarch)),
      Label("@go_stdlib_{}_{}_cgo_race".format(goos, goarch)),
      Label("@go_stdlib_{}_{}_pure_race".format(goos, goarch)),
    ])
  return stdlibs

def _go_context_data(ctx):
    return struct(
        strip = ctx.attr.strip,
        stdlib_all = ctx.attr._stdlib_all,
        crosstool = ctx.files._crosstool,
        package_list = ctx.file._package_list,
    )

go_context_data = rule(
    _go_context_data,
    attrs = {
        "strip": attr.string(mandatory=True),
        # Hidden internal attributes
        "_stdlib_all": attr.label_list(default = _stdlib_all()),
        "_crosstool": attr.label(default=Label("//tools/defaults:crosstool")),
        "_package_list": attr.label(allow_files = True, single_file = True, default="@go_sdk//:packages.txt"),
    },
)
