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

DEFAULT_LIB = "go_default_library"
VENDOR_PREFIX = "/vendor/"

NORMAL_MODE = "normal"
RACE_MODE = "race"

compile_modes = (NORMAL_MODE, RACE_MODE)

go_exts = [
    ".go",
]

asm_exts = [
    ".s",
    ".S",
    ".h",  # may be included by .s
]

# be consistent to cc_library.
hdr_exts = [
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".inc",
]

c_exts = [
    ".c",
    ".cc",
    ".cxx",
    ".cpp",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
]

go_filetype = FileType(go_exts + asm_exts)
cc_hdr_filetype = FileType(hdr_exts)

# Extensions of files we can build with the Go compiler or with cc_library.
# This is a subset of the extensions recognized by go/build.
cgo_filetype = FileType(go_exts + asm_exts + c_exts)

def pkg_dir(workspace_root, package_name):
  """Returns a relative path to a package directory from the root of the
  sandbox. Useful at execution-time or run-time."""
  if workspace_root and package_name:
    return workspace_root + "/" + package_name
  if workspace_root:
    return workspace_root
  if package_name:
    return package_name
  return "."

def dict_of(st):
  """Converts struct objects into dictionaries."""
  data = dict()
  for key in dir(st):
    value = getattr(st, key, None)
    if value != None: # skip methods
      data[key] = value
  return data


def split_srcs(srcs):
  go = depset()
  headers = depset()
  asm = depset()
  c = depset()
  for src in srcs:
    if any([src.basename.endswith(ext) for ext in go_exts]):
      go += [src]
    elif any([src.basename.endswith(ext) for ext in hdr_exts]):
      headers += [src]
    elif any([src.basename.endswith(ext) for ext in asm_exts]):
      asm += [src]
    elif any([src.basename.endswith(ext) for ext in c_exts]):
      c += [src]
    else:
      fail("Unknown source type {0}".format(src.basename))
  return struct(
      go = go,
      headers = headers,
      asm = asm,
      c = c,
  )

def join_srcs(source):
  return depset() + source.go + source.headers + source.asm + source.c
