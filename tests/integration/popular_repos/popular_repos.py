#!/usr/bin/env python
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

from subprocess import check_output, call
from sys import exit

POPULAR_REPOS = [
    dict(
        name = "org_golang_x_crypto",
        importpath = "golang.org/x/crypto",
        urls = ["https://codeload.github.com/golang/crypto/zip/81e90905daefcd6fd217b62423c0908922eadb30"],
        strip_prefix = "crypto-81e90905daefcd6fd217b62423c0908922eadb30",
        type = "zip",
        excludes = [
            "ssh/agent:go_default_test",
            "ssh:go_default_test",
            "ssh/test:go_default_test",
        ],
    ),

    dict(
        name = "org_golang_x_net",
        importpath = "golang.org/x/net",
        commit = "57efc9c3d9f91fb3277f8da1cff370539c4d3dc5",
        excludes = [
            "bpf:go_default_test", # Needs testdata directory
            "html/charset:go_default_test", # Needs testdata directory
            "http2:go_default_test", # Needs testdata directory
            "icmp:go_default_test", # icmp requires adjusting kernel options.
            "nettest:go_default_test", #
            "lif:go_default_test",
        ],
        darwin_tests = [
            "route:go_default_test", # Not supported on linux
        ]
    ),

    dict(
        name = "org_golang_x_sys",
        importpath = "golang.org/x/sys",
        commit = "0b25a408a50076fbbcae6b7ac0ea5fbb0b085e79",
        excludes = [
            "unix:go_default_test", # TODO(#413): External test depends on symbols defined in internal test.
        ],
    ),

    dict(
        name = "org_golang_x_text",
        importpath = "golang.org/x/text",
        commit = "a9a820217f98f7c8a207ec1e45a874e1fe12c478",
        excludes = [
            "encoding/japanese:go_default_test", # Needs testdata directory
            "encoding/korean:go_default_test", # Needs testdata directory
            "encoding/charmap:go_default_test", # Needs testdata directory
            "encoding/simplifiedchinese:go_default_test", # Needs testdata directory
            "encoding/traditionalchinese:go_default_test", # Needs testdata directory
            "encoding/unicode/utf32:go_default_test", # Needs testdata directory
            "encoding/unicode:go_default_test", # Needs testdata directory
            "internal/cldrtree:go_default_test", # Needs testdata directory
        ],
    ),

    dict(
        name = "org_golang_x_tools",
        importpath = "golang.org/x/tools",
        commit = "663269851cdddc898f963782f74ea574bcd5c814",
        excludes = [
            "cmd/bundle:go_default_test", # Needs testdata directory
            "cmd/callgraph:go_default_test", # Needs testdata directory
            "cmd/cover:go_default_test", # Needs testdata directory
            "cmd/guru:go_default_test", # Needs testdata directory
            "cmd/stringer:go_default_test", # Needs testdata directory
            "go/buildutil:go_default_test", # Needs testdata directory
            "go/callgraph/cha:go_default_test", # Needs testdata directory
            "go/callgraph/rta:go_default_test", # Needs testdata directory
            "go/gccgoexportdata:go_default_test", # Needs testdata directory
            "go/gcexportdata:go_default_test", # Needs testdata directory
            "go/gcimporter15:go_default_test", # Needs testdata directory
            "go/internal/gccgoimporter:go_default_test", # Needs testdata directory
            "go/loader:go_default_test", # Needs testdata directory
            "go/pointer:go_default_test", # Needs testdata directory
            "go/ssa/interp:go_default_test", # Needs testdata directory
            "go/ssa/ssautil:go_default_test", # Needs testdata directory
            "go/ssa:go_default_test", # Needs testdata directory
            "refactor/eg:go_default_test", # Needs testdata directory
            "cmd/fiximports:go_default_test", # requires working GOROOT, not present in CI.
            "cmd/godoc:go_default_test", # TODO(#417)
            "cmd/gorename:go_default_test", # TODO(#417)
            "go/gcimporter15:go_default_test", # TODO(#417)
            "refactor/importgraph:go_default_test", # TODO(#417)
            "refactor/rename:go_default_test", # TODO(#417)
            "cmd/guru/testdata/src/referrers:go_default_test", # Not a real test
            "container/intsets:go_default_test", # TODO(#413): External test depends on symbols defined in internal test.
        ],
    ),

    dict(
        name = "org_golang_google_grpc",
        importpath = "google.golang.org/grpc",
        commit = "3f10311ccf076b6b7cba28273df3290d42e60982",

        # GRPC has already-generated protobuf definitions, and we don't currently
        # register any protobuf toolchains in this WORKSPACE.  As such, the build
        # should fail if we try to generate protobuf rules, but succeed if we
        # disable generation.
        build_file_proto_mode = "disable",
        excludes = [
            "test:go_default_test",
            "examples/route_guide/mock_routeguide:go_default_test",
            "examples/helloworld/mock_helloworld:go_default_test",
            "credentials:go_default_test",
            "credentials/alts:go_default_test", # not supported on darwin
            ":go_default_test",
            "transport:go_default_test", # slow
        ],
    ),

    dict(
        name = "com_github_mattn_go_sqlite3",
        importpath = "github.com/mattn/go-sqlite3",
        commit = "83772a7051f5e30d8e59746a9e43dfa706b72f3b",
        excludes = [],
    ),
  ]

COPYRIGHT_HEADER = """
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

##############################
# Generated file, do not edit!
##############################
""".strip()

BZL_HEADER = COPYRIGHT_HEADER + """

load("@io_bazel_rules_go//go/private:go_repository.bzl", "go_repository")

def _maybe(repo_rule, name, **kwargs):
  if name not in native.existing_rules():
    repo_rule(name=name, **kwargs)

def popular_repos():
"""

BUILD_HEADER = COPYRIGHT_HEADER

DOCUMENTATION_HEADER = """
Popular repository tests
========================

These tests are designed to check that gazelle and rules_go together can cope
with a list of popluar repositories people depend on.

It helps catch changes that might break a large number of users.

.. contents::

""".lstrip()

def popular_repos_bzl():
  with open("popular_repos.bzl", "w") as f:
    f.write(BZL_HEADER)
    for repo in POPULAR_REPOS:
      f.write("  _maybe(\n    go_repository,\n")
      for k in ["name", "importpath", "commit", "strip_prefix", "type", "build_file_proto_mode"]:
        if k in repo: f.write('    {}="{}",\n'.format(k, repo[k]))
      for k in ["urls"]:
        if k in repo: f.write('    {}={},\n'.format(k, repo[k]))
      f.write("  )\n")

def build_bazel():
  with open("BUILD.bazel", "w") as f:
    f.write(BUILD_HEADER)
    for repo in POPULAR_REPOS:
      name = repo["name"]
      tests = check_output(["bazel", "query", "kind(go_test, \"@{}//...\")".format(name)]).split("\n")
      excludes = ["@{}//{}".format(name, l) for l in repo.get("excludes", [])]
      for k in repo:
        if k.endswith("_excludes") or k.endswith("_tests"):
          excludes.extend(["@{}//{}".format(name, l) for l in repo[k]])
      invalid_excludes = [t for t in excludes if not t in tests]
      if invalid_excludes:
        exit("Invalid excludes found: {}".format(invalid_excludes))
      f.write('\ntest_suite(\n')
      f.write('    name = "{}",\n'.format(name))
      f.write('    tests = [\n')
      actual = []
      for test in sorted(tests, key=lambda test: test.replace(":", "!")):
        if test in excludes or not test: continue
        f.write('        "{}",\n'.format(test))
        actual.append(test)
      f.write('    ],\n')
      #TODO: add in the platform "select" tests
      f.write(')\n')
      repo["actual"] = actual

def readme_rst():
  with open("README.rst", "w") as f:
    f.write(DOCUMENTATION_HEADER)
    for repo in POPULAR_REPOS:
      name = repo["name"]
      f.write("{}\n{}\n\n".format(name, "_"*len(name)))
      f.write("This runs tests from the repository `{0} <https://{0}>`_\n\n".format(repo["importpath"]))
      for test in repo["actual"]:
          f.write("* {}\n".format(test))
      f.write("\n\n")


def main():
  popular_repos_bzl()
  build_bazel()
  readme_rst()

if __name__ == "__main__":
    main()
