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
    ":providers.bzl",
    "GoCcInfo",
    "GoSource",
)

def _go_cc_aspect_impl(target, _ctx):
    if CcInfo in target:
        return [GoCcInfo(cc_info = target[CcInfo])]

    if GoSource in target:
        cc_infos = []
        source = target[GoSource]
        for dep in source.deps + source.cdeps:
            if GoCcInfo in dep:
                cc_infos.append(dep[GoCcInfo].cc_info)
        return [
            GoCcInfo(cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)),
        ]

    return None

go_cc_aspect = aspect(
    implementation = _go_cc_aspect_impl,
    attr_aspects = ["deps"],
)
