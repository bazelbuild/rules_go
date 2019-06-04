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

load(
    "@io_bazel_rules_go//go/private:platforms.bzl",
    "PLATFORMS",
    _GOOS_GOARCH = "GOOS_GOARCH",
    _MSAN_GOOS_GOARCH = "MSAN_GOOS_GOARCH",
    _RACE_GOOS_GOARCH = "RACE_GOOS_GOARCH",
)

GOOS_GOARCH = _GOOS_GOARCH
RACE_GOOS_GOARCH = _RACE_GOOS_GOARCH
MSAN_GOOS_GOARCH = _MSAN_GOOS_GOARCH

GOOS = {p.goos: p.os_constraint for p in PLATFORMS if p.has_default_constraints}
GOARCH = {p.goarch: p.arch_constraint for p in PLATFORMS if p.has_default_constraints}

def declare_config_settings():
    for goos in GOOS:
        native.config_setting(
            name = goos,
            constraint_values = ["@io_bazel_rules_go//go/toolchain:" + goos],
        )
    for goarch in GOARCH:
        native.config_setting(
            name = goarch,
            constraint_values = ["@io_bazel_rules_go//go/toolchain:" + goarch],
        )
    for p in PLATFORMS:
        if not p.has_default_constraints:
            continue  # skip special platforms
        native.config_setting(
            name = p.name,
            constraint_values = [
                p.os_constraint,
                p.arch_constraint,
            ],
        )
