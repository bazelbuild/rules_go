# Copyright 2019 The Bazel Authors. All rights reserved.
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
    "@io_bazel_rules_go//go:def.bzl",
    _go_download_sdk = "go_download_sdk",
    _go_host_sdk = "go_host_sdk",
    _go_local_sdk = "go_local_sdk",
    _go_register_toolchains = "go_register_toolchains",
    _go_rules_dependencies = "go_rules_dependencies",
    _go_wrap_sdk = "go_wrap_sdk",
)

go_rules_dependencies = _go_rules_dependencies
go_register_toolchains = _go_register_toolchains
go_download_sdk = _go_download_sdk
go_host_sdk = _go_host_sdk
go_local_sdk = _go_local_sdk
go_wrap_sdk = _go_wrap_sdk
