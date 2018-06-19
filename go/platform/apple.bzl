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

PLATFORMS = {
    "armv7-apple-ios": apple_common.platform.ios_device,
    "armv7-apple-tvos": apple_common.platform.tvos_device,
    "armv7k-apple-watchos": apple_common.platform.watchos_device,
    "arm64-apple-ios": apple_common.platform.ios_device,
    "arm64-apple-tvos": apple_common.platform.tvos_device,
    "i386-apple-ios": apple_common.platform.ios_simulator,
    "i386-apple-tvos": apple_common.platform.tvos_simulator,
    "i386-apple-watchos": apple_common.platform.watchos_simulator,
    "x86_64-apple-ios": apple_common.platform.ios_simulator,
    "x86_64-apple-tvos": apple_common.platform.ios_simulator,
    "x86_64-apple-watchos": apple_common.platform.watchos_simulator,
}

def _apple_version_min(platform, version):
    return "-m" + platform.name_in_plist.lower() + "-version-min=" + version

def apple_ensure_options(ctx, env, tags, compiler_options, linker_options):
    """apple_ensure_options ensures that, when building an Apple target, the
    proper environment, compiler flags and Go tags are correctly set."""
    system_name = ctx.fragments.cpp.target_gnu_system_name
    platform = PLATFORMS.get(system_name)
    if platform == None:
        return
    if system_name.endswith("-ios"):
        tags.append("ios")  # needed for stdlib building
    if platform in [apple_common.platform.ios_device, apple_common.platform.ios_simulator]:
        min_version = _apple_version_min(platform, "7.0")
        compiler_options.append(min_version)
        linker_options.append(min_version)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    env.update(apple_common.target_apple_env(xcode_config, platform))
