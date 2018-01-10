# Copyright 2018 The Bazel Authors. All rights reserved.
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
    "@io_bazel_rules_go//go/private:rules/aspect.bzl",
    "go_archive_aspect",
)

def go_rule(implementation, attrs={}, toolchains=[], bootstrap=False, **kwargs):
  if not bootstrap:
    attrs["_go_context_data"] = attr.label(default = Label("@io_bazel_rules_go//:go_context_data"))
    toolchains = toolchains + ["@io_bazel_rules_go//go:toolchain"]
  else:
    attrs["_go_context_data"] = attr.label(default = Label("@io_bazel_rules_go//:go_bootstrap_context_data"))
    toolchains = toolchains + ["@io_bazel_rules_go//go:bootstrap_toolchain"]

  return rule(
      implementation = implementation,
      attrs = attrs,
      toolchains = toolchains,
      **kwargs
  )