# Copyright 2020 The Bazel Authors. All rights reserved.
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

def _match_apple(_crosstool_top, cpu):
    """_match_apple will try to detect wether the inbound crosstool/cpu is
    targeting the Apple ecosystem. Apple crosstool CPUs are prefixed, so
    matching is easy."""
    platform = {
        "darwin": "darwin_amd64",
        "darwin_x86_64": "darwin_amd64",
        "darwin_arm64": "darwin_arm64",
        "ios_arm64": "ios_arm64",
        "ios_armv7": "ios_arm",
        "ios_i386": "ios_386",
        "ios_x86_64": "ios_amd64",
    }.get(cpu)
    if platform:
        return "{}_cgo".format(platform)
    return None

def _match_android(crosstool_top, cpu):
    """_match_android will try to detect wether the inbound crosstool is the
    Android NDK toolchain. It can either be `//external:android/crosstool` or be
    part of the `@androidndk` workspace. After that, translate Android CPUs to
    Go CPUs."""
    if str(crosstool_top) == "//external:android/crosstool" or \
       crosstool_top.workspace_name == "androidndk":
        platform_cpu = {
            "arm64-v8a": "arm64",
            "armeabi-v7a": "arm",
            "x86": "386",
            "x86_64": "amd64",
        }.get(cpu)
        if platform_cpu:
            return "android_{}_cgo".format(platform_cpu)
    return None

def platform_from_crosstool(crosstool_top, cpu):
    """platform_from_crosstool runs matchers against the crosstool_top/cpu pair
    to automatically infer the target platform."""
    matchers = [
        _match_apple,
        _match_android,
    ]
    for matcher in matchers:
        platform = matcher(crosstool_top, cpu)
        if platform:
            return "@io_bazel_rules_go//go/toolchain:{}".format(platform)
    return None
