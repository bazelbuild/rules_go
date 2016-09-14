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

"""Permitted combinations from
https://golang.org/doc/install/source#environment.  Pronounced
"goose-garch" (https://www.youtube.com/watch?v=KINIAgRpkDA).
"""
GOOS_GOARCH = [
  "android_arm",
  "darwin_386",
  "darwin_amd64",
  "darwin_arm",
  "darwin_arm64",
  "dragonfly_amd64",
  "freebsd_386",
  "freebsd_amd64",
  "freebsd_arm",
  "linux_386",
  "linux_amd64",
  "linux_arm",
  "linux_arm64",
  "linux_ppc64",
  "linux_ppc64le",
  "linux_mips64",
  "linux_mips64le",
  "netbsd_386",
  "netbsd_amd64",
  "netbsd_arm",
  "openbsd_386",
  "openbsd_amd64",
  "openbsd_arm",
  "plan9_386",
  "plan9_amd64",
  "solaris_amd64",
  "windows_386",
  "windows_amd64",
]
