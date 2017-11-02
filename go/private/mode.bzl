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

# Modes are documented in go/modes.rst#compilation-modes

LINKMODE_NORMAL = "normal"
LINKMODE_SHARED = "shared"
LINKMODE_PIE = "pie"
LINKMODE_PLUGIN = "plugin"

def mode_string(mode):
  result = []
  if mode.static:
    result.append("static")
  if mode.race:
    result.append("race")
  if mode.msan:
    result.append("msan")
  if mode.pure:
    result.append("pure")
  if mode.debug:
    result.append("debug")
  if mode.strip:
    result.append("stripped")
  if not result or not mode.link == LINKMODE_NORMAL:
    result.append(mode.link)
  return "_".join(result)

def _ternary(*values):
  for v in values:
    if v == None: continue
    if type(v) == "bool": return v
    if type(v) != "string": fail("Invalid value type {}".format(type(v)))
    v = v.lower()
    if v == "on": return True
    if v == "off": return False
    if v == "auto": continue
    fail("Invalid value {}".format(v))
  fail("_ternary failed to produce a final result from {}".format(values))

def get_mode(ctx):
  force_pure = None
  if "@io_bazel_rules_go//go:toolchain" in ctx.toolchains:
    if ctx.toolchains["@io_bazel_rules_go//go:toolchain"].cross_compile:
      # We always have to user the pure stdlib in cross compilation mode
      force_pure = True

  #TODO: allow link mode selection
  features = ctx.features if ctx != None else []
  toolchain_flags = getattr(ctx.attr, "_go_toolchain_flags", None)
  debug = False
  strip = True
  if toolchain_flags:
    debug = toolchain_flags.compilation_mode == "debug"
    if toolchain_flags.strip == "always":
      strip = True
    elif toolchain_flags.strip == "sometimes":
      strip = not debug
  return struct(
      static = _ternary(
          getattr(ctx.attr, "static", None),
          "static" in features,
      ),
      race = _ternary(
          "race" in features,
      ),
      msan = _ternary(
          "msan" in features,
      ),
      pure = _ternary(
          getattr(ctx.attr, "pure", None),
          force_pure,
          "pure" in features,
      ),
      link = LINKMODE_NORMAL,
      debug = debug,
      strip = strip,
  )
