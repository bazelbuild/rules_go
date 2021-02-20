# Copyright 2021 The Bazel Authors. All rights reserved.
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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _rpath(go, library, relative_to = None):
    """Returns the rpath of a library, possibly relative to another file."""
    if not relative_to:
        return paths.dirname(library.short_path)

    # Go back to the workspace root from the executable file
    depth = relative_to.short_path.count("/")
    back_to_root = paths.join(*([".."] * depth))
    origin = go.mode.goos == "darwin" and "@loader_path" or "$ORIGIN"

    # Then walk back to the library's short path
    return paths.join(origin, back_to_root, paths.dirname(library.short_path))

def _flag(go, *args, **kwargs):
    """Returns the linker flag rpath for a library."""
    return "-Wl,-rpath," + _rpath(go, *args, **kwargs)

def _install_name(f):
    """Returns the install name for a dylib on macOS."""
    return f.short_path

rpath = struct(
    flag = _flag,
    install_name = _install_name,
    rpath = _rpath,
)
