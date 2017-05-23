# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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

def _go_root_impl(ctx):
  """go_root_impl propogates a GOROOT path string."""
  return struct(path = ctx.attr.path)

go_root = rule(
  _go_root_impl,
  attrs = {
    "path": attr.string(mandatory = True),
  },
)
"""Captures the goroot value for use as a label dependency.

Args:
  path (string): the absolute path to GOROOT.

Returns:
  (struct): .go_root (string): the GOROOT value provider.

"""
