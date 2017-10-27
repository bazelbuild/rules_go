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

def mode(base=None, static=None, race=None, msan=None, pure=None, link=None):
  if static == None: static = base.static
  if race == None: race = base.race
  if msan == None: msan = base.msan
  if pure == None: pure = base.pure
  if link == None: link = base.link
  return struct(
      static = static,
      race = race,
      msan = msan,
      pure = pure,
      link = link,
  )

DEFAULT_MODE = mode(
    static = False,
    race = False,
    msan = False,
    pure = False,
    link = LINKMODE_NORMAL,
)

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
  if not result or not mode.link == LINKMODE_NORMAL:
    result.append(mode.link)
  return "_".join(result)

NORMAL_MODE = DEFAULT_MODE
RACE_MODE = mode(base = DEFAULT_MODE, race=True)
STATIC_MODE = mode(base = DEFAULT_MODE, static=True)

common_modes = (NORMAL_MODE, RACE_MODE, STATIC_MODE)

def get_mode(ctx):
  #TODO: allow ctx.attr to override the feature driven defaults
  #TODO: allow link mode selection
  return mode(
      base=DEFAULT_MODE,
      static = True if "static" in ctx.features else False,
      race = True if "race" in ctx.features else False,
      msan = True if "msan" in ctx.features else False,
      pure = True if "pure" in ctx.features else False,
      link = LINKMODE_NORMAL,
  )