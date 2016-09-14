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

def _go_prefix_impl(ctx):
  """go_prefix_impl provides the go prefix to use as a transitive info provider."""
  return struct(go_prefix = ctx.attr.prefix)

_go_prefix_rule = rule(
    _go_prefix_impl,
    attrs = {
        "prefix": attr.string(mandatory = True),
    },
)

def go_prefix(prefix):
  """go_prefix sets the Go import name to be used for this workspace."""
  _go_prefix_rule(name = "go_prefix",
    prefix = prefix,
    visibility = ["//visibility:public" ]
  )
"""Capture the go_prefix for use as a label dependency.

In Go, imports are always fully qualified with a URL,
eg. github.com/user/project. Hence, a label //foo:bar from within a
Bazel workspace must be referred to as
"github.com/user/project/foo/bar". To make this work, each rule must
know the repository's URL. This is achieved, by having all go rules
depend on a globally unique target that has a "go_prefix" transitive
info provider.

Args:
  prefix (string): the import prefix, typically similar to 'github.com/user/project'.

Returns:
  (struct): .go_prefix (string) provider.

"""
