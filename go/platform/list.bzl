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
    _GOARCH = "GOARCH_CONSTRAINTS",
    _GOOS = "GOOS_CONSTRAINTS",
    _GOOS_GOARCH = "GOOS_GOARCH",
    _MSAN_GOOS_GOARCH = "MSAN_GOOS_GOARCH",
    _RACE_GOOS_GOARCH = "RACE_GOOS_GOARCH",
)

GOOS_GOARCH = _GOOS_GOARCH
GOOS = _GOOS
GOARCH = _GOARCH
RACE_GOOS_GOARCH = _RACE_GOOS_GOARCH
MSAN_GOOS_GOARCH = _MSAN_GOOS_GOARCH

def _os_constraint(goos):
    if goos == "darwin":
        return "@io_bazel_rules_go//go/toolchain:is_darwin"
    else:
        return "@io_bazel_rules_go//go/toolchain:" + goos

def _arch_constraint(goarch):
    return "@io_bazel_rules_go//go/toolchain:" + goarch

def declare_config_settings():
    """Generates config_setting targets for each goos, goarch, and valid
    goos_goarch pair. These targets may be used in select expressions.
    Each target refers to a corresponding constraint_value in //go/toolchain.

    Note that the "darwin" targets are true when building for either
    macOS or iOS.
    """
    for goos in GOOS:
        native.config_setting(
            name = goos,
            constraint_values = [_os_constraint(goos)],
        )
    for goarch in GOARCH:
        native.config_setting(
            name = goarch,
            constraint_values = [_arch_constraint(goarch)],
        )
    for goos, goarch in GOOS_GOARCH:
        native.config_setting(
            name = goos + "_" + goarch,
            constraint_values = [
                _os_constraint(goos),
                _arch_constraint(goarch),
            ],
        )
