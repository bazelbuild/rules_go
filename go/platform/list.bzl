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

GOOS = {
    "darwin": "@bazel_tools//platforms:osx",
    "dragonfly": None,
    "linux": "@bazel_tools//platforms:linux",
    "android": None,
    "solaris": None,
    "freebsd": "@bazel_tools//platforms:freebsd",
    "nacl": None,
    "netbsd": None,
    "openbsd": None,
    "plan9": None,
    "windows": "@bazel_tools//platforms:windows",
}

GOARCH = {
    "386": "@bazel_tools//platforms:x86_32",
    "amd64": "@bazel_tools//platforms:x86_64",
    "amd64p32": None,
    "arm": "@bazel_tools//platforms:arm",
    "arm64": None,
    "mips": None,
    "mipsle": None,
    "mips64": None,
    "mips64le": None,
    "ppc64": "@bazel_tools//platforms:ppc",
    "ppc64le": None,
    "s390x": None,
}

GOOS_GOARCH = (
    ("darwin", "386"),
    ("darwin", "amd64"),
    ("darwin", "arm"),
    ("darwin", "arm64"),
    ("dragonfly", "amd64"),
    ("freebsd", "386"),
    ("freebsd", "amd64"),
    ("freebsd", "arm"),
    ("linux", "386"),
    ("linux", "amd64"),
    ("linux", "arm"),
    ("linux", "arm64"),
    ("linux", "ppc64"),
    ("linux", "ppc64le"),
    ("linux", "mips"),
    ("linux", "mipsle"),
    ("linux", "mips64"),
    ("linux", "mips64le"),
    ("linux", "s390x"),
    ("android", "386"),
    ("android", "amd64"),
    ("android", "arm"),
    ("android", "arm64"),
    ("nacl", "386"),
    ("nacl", "amd64p32"),
    ("nacl", "arm"),
    ("netbsd", "386"),
    ("netbsd", "amd64"),
    ("netbsd", "arm"),
    ("openbsd", "386"),
    ("openbsd", "amd64"),
    ("openbsd", "arm"),
    ("plan9", "386"),
    ("plan9", "amd64"),
    ("plan9", "arm"),
    ("solaris", "amd64"),
    ("windows", "386"),
    ("windows", "amd64"),
)

def declare_constraints():
  for goos, constraint in GOOS.items():
    if constraint:
      native.alias(
          name = goos,
          actual = constraint,
      )
    else:
      native.constraint_value(
          name = goos,
          constraint_setting = "@bazel_tools//platforms:os",
      )
  for goarch, constraint in GOARCH.items():
    if constraint:
      native.alias(
          name = goarch,
          actual = constraint,
      )
    else:
      native.constraint_value(
          name = goarch,
          constraint_setting = "@bazel_tools//platforms:cpu",
      )
  for goos, goarch in GOOS_GOARCH:
      native.platform(
        name = goos + "_" + goarch,
        constraint_values = [
            ":" + goos,
            ":" + goarch,
        ],
      )
