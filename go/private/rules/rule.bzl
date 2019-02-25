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

_ASPECT_ATTRS = ["pure", "static", "msan", "race"]

# Keep in sync with attr_aspects in go_archive_aspect. Any implicit dependency
# that is built in the target configuration should go there.
_BOOTSTRAP_ATTRS = ["_coverdata", "_stdlib", "_nogo"]

def go_rule(implementation, attrs = None, toolchains = None, bootstrap = False, bootstrap_attrs = _BOOTSTRAP_ATTRS, **kwargs):
    attrs = attrs if attrs else {}
    toolchains = toolchains if toolchains else []
    if bootstrap:
        bootstrap_attrs = []

    attrs["_go_context_data"] = attr.label(default = "@io_bazel_rules_go//:go_context_data")
    aspects = []

    # If all the aspect attributes are present, also trigger the aspect on the stdlib attribute
    if all([k in attrs for k in _ASPECT_ATTRS]):
        aspects.append(go_archive_aspect)
    toolchains = toolchains + ["@io_bazel_rules_go//go:toolchain"]

    if "_nogo" in bootstrap_attrs:
        attrs["_nogo"] = attr.label(default = Label("@io_bazel_rules_nogo//:nogo"), cfg = "host")
    if "_coverdata" in bootstrap_attrs:
        attrs["_coverdata"] = attr.label(default = "@io_bazel_rules_go//go/tools/coverdata", aspects = aspects)
    if "_stdlib" in bootstrap_attrs:
        attrs["_stdlib"] = attr.label(default = "@io_bazel_rules_go//:stdlib", aspects = aspects)

    return rule(
        implementation = implementation,
        attrs = attrs,
        toolchains = toolchains,
        **kwargs
    )
