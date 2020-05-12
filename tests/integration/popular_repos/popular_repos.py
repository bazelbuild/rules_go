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
        urls = "https://codeload.github.com/golang/crypto/zip/de0752318171da717af4ce24d0a2e8626afaeb11",
        strip_prefix = "crypto-de0752318171da717af4ce24d0a2e8626afaeb11",
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
            "ipv4:go_default_test", # 1877 (but new in go1.13): conflicting package heights
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
        commit = "acbc56fc7007d2a01796d5bde54f39e3b3e95945",
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
        ],
    ),

    dict(
        name = "org_golang_x_tools",
        importpath = "golang.org/x/tools",
        commit = "11eff242d136374289f76e9313c76e9312391172",
        excludes = [
            "blog:go_default_test", # Needs goldmark
            "cmd/bundle:go_default_test", # Needs testdata directory
            "cmd/callgraph/testdata/src/pkg:go_default_test", # is testdata
            "cmd/callgraph:go_default_test", # Needs testdata directory
            "cmd/cover:go_default_test", # Needs testdata directory
            "cmd/fiximports:go_default_test", # requires working GOROOT, not present in CI.
            "cmd/godoc:go_default_test", # TODO(#417)
            "cmd/gorename:go_default_test", # TODO(#417)
            "cmd/guru/testdata/src/referrers:go_default_test", # Not a real test
            "cmd/guru:go_default_test", # Needs testdata directory
            "cmd/stringer:go_default_test", # Needs testdata directory
            "container/intsets:go_default_test", # TODO(#413): External test depends on symbols defined in internal test.
            "go/analysis/analysistest:go_default_test", # requires build cache
            "go/analysis/internal/checker:go_default_test", # loads test package with go/packages, which probably needs go list
            "go/analysis/internal/facts:go_default_test", # loads test package with go/packages, which probably needs go list
            "go/analysis/multichecker:go_default_test", # requires go vet
            "go/analysis/passes/asmdecl:go_default_test", # Needs testdata directory
            "go/analysis/passes/assign:go_default_test", # Needs testdata directory
            "go/analysis/passes/atomic:go_default_test", # Needs testdata directory
            "go/analysis/passes/atomicalign:go_default_test", # requires go list
            "go/analysis/passes/bools:go_default_test", # Needs testdata directory
            "go/analysis/passes/buildssa:go_default_test", # Needs testdata directory
            "go/analysis/passes/buildtag:go_default_test", # Needs testdata directory
            "go/analysis/passes/cgocall:go_default_test", # Needs testdata directory
            "go/analysis/passes/composite:go_default_test", # Needs testdata directory
            "go/analysis/passes/copylock:go_default_test", # Needs testdata directory
            "go/analysis/passes/ctrlflow:go_default_test", # Needs testdata directory
            "go/analysis/passes/deepequalerrors:go_default_test", # requires go list
            "go/analysis/passes/errorsas:go_default_test", # requires go list and testdata
            "go/analysis/passes/findcall:go_default_test", # requires build cache
            "go/analysis/passes/httpresponse:go_default_test", # Needs testdata directory
            "go/analysis/passes/ifaceassert:go_default_test", # Needs GOROOT
            "go/analysis/passes/loopclosure:go_default_test", # Needs testdata directory
            "go/analysis/passes/lostcancel:go_default_test", # Needs testdata directory
            "go/analysis/passes/nilfunc:go_default_test", # Needs testdata directory
            "go/analysis/passes/nilness:go_default_test", # Needs testdata directory
            "go/analysis/passes/pkgfact:go_default_test", # requires go list
            "go/analysis/passes/printf:go_default_test", # Needs testdata directory
            "go/analysis/passes/shadow:go_default_test", # Needs testdata directory
            "go/analysis/passes/shift:go_default_test", # Needs testdata directory
            "go/analysis/passes/sortslice:go_default_test", # Needs 'go list'
            "go/analysis/passes/stdmethods:go_default_test", # Needs testdata directory
            "go/analysis/passes/stringintconv:go_default_test", # Needs 'go list'
            "go/analysis/passes/structtag:go_default_test", # Needs testdata directory
            "go/analysis/passes/testinggoroutine:go_default_test", # Need 'go env'
            "go/analysis/passes/tests/testdata/src/a:go_default_test", # Not a real test
            "go/analysis/passes/tests/testdata/src/b_x_test:go_default_test", # Not a real test
            "go/analysis/passes/tests/testdata/src/divergent:go_default_test", # Not a real test
            "go/analysis/passes/tests:go_default_test", # Needs testdata directory
            "go/analysis/passes/unmarshal:go_default_test", # Needs go list
            "go/analysis/passes/unreachable:go_default_test", # Needs testdata directory
            "go/analysis/passes/unsafeptr:go_default_test", # Needs testdata directory
            "go/analysis/passes/unusedresult:go_default_test", # Needs testdata directory
            "go/analysis/unitchecker:go_default_test", # requires go vet
            "go/ast/inspector:go_default_test", # requires GOROOT and GOPATH
            "go/buildutil:go_default_test", # Needs testdata directory
            "go/callgraph/cha:go_default_test", # Needs testdata directory
            "go/callgraph/rta:go_default_test", # Needs testdata directory
            "go/expect:go_default_test", # Needs testdata directory
            "go/gccgoexportdata:go_default_test", # Needs testdata directory
            "go/gcexportdata:go_default_test", # Needs testdata directory
            "go/internal/gccgoimporter:go_default_test", # Needs testdata directory
            "go/internal/gcimporter:go_default_test", # Needs testdata directory
            "go/loader:go_default_test", # Needs testdata directory
            "go/packages/packagestest/testdata/groups/two/primarymod/expect:go_default_test", # Is testdata
            "go/packages/packagestest/testdata:go_default_test", # Is testdata
            "go/packages/packagestest:go_default_test", # requires build cache
            "go/packages:go_default_test", # Hah!
            "go/pointer:go_default_test", # Needs testdata directory
            "go/ssa/interp:go_default_test", # Needs testdata directory
            "go/ssa/ssautil:go_default_test", # Needs testdata directory
            "go/ssa:go_default_test", # Needs testdata directory
            "go/types/typeutil:go_default_test", # requires GOROOT
            "godoc/static:go_default_test", # requires data files
            "godoc/vfs/zipfs:go_default_test", # requires GOROOT
            "godoc:go_default_test", # requires GOROOT and GOPATH
            "internal/apidiff:go_default_test", # Needs testdata directory
            "internal/gocommand:go_default_test", # Needs go tool
            "internal/imports:go_default_test", # Needs testdata directory
            "internal/lsp/analysis/fillreturns:go_default_test", # Needs go tool
            "internal/lsp/analysis/nonewvars:go_default_test", # Needs GOROOT
            "internal/lsp/analysis/noresultvalues:go_default_test", # Needs GOROOT
            "internal/lsp/analysis/simplifycompositelit:go_default_test", # Needs go tool
            "internal/lsp/analysis/simplifyrange:go_default_test", # Needs GOROOT
            "internal/lsp/analysis/simplifyslice:go_default_test", # Needs GOROOT
            "internal/lsp/analysis/undeclaredname:go_default_test", # Needs GOROOT
            "internal/lsp/analysis/unusedparams:go_default_test", # Needs go tool
            "internal/lsp/cache:go_default_test", # has additional deps
            "internal/lsp/cmd:go_default_test", # panics?
            "internal/lsp/diff/difftest:go_default_test", # has additional deps
            "internal/lsp/diff/myers:go_default_test", # has additional deps
            "internal/lsp/diff:go_default_test", # has additional deps
            "internal/lsp/fake:go_default_test", # has additional deps
            "internal/lsp/fuzzy:go_default_test", # has additional deps
            "internal/lsp/lsprpc:go_default_test", # has additional deps
            "internal/lsp/mod:go_default_test", # has additional deps
            "internal/lsp/regtest:go_default_test", # has additional deps
            "internal/lsp/snippet:go_default_test", # has additional deps
            "internal/lsp/source:go_default_test", # Needs testdata directory
            "internal/lsp/testdata/lsp/primarymod/analyzer:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/codelens:go_default_test", # Is testdata
            "internal/lsp/testdata/lsp/primarymod/godef/a:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/implementation/other:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/references:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/rename/testy:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/signature:go_default_test", # Is testdata
            "internal/lsp/testdata/lsp/primarymod/testy:go_default_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/unimported:go_default_test", # not a real test
            "internal/lsp:go_default_test", # Needs testdata directory
            "present:go_default_test", # Needs goldmark
            "refactor/eg:go_default_test", # Needs testdata directory
            "refactor/importgraph:go_default_test", # TODO(#417)
            "refactor/rename:go_default_test", # TODO(#417)
        ],
    ),

    dict(
        name = "com_github_golang_glog",
        importpath = "github.com/golang/glog",
        commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
    ),

    dict(
        name = "org_golang_x_sync",
        importpath = "golang.org/x/sync",
        commit = "112230192c580c3556b8cee6403af37a4fc5f28c",
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

load("@bazel_gazelle//:def.bzl", "go_repository")

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)

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
      f.write("    _maybe(\n        go_repository,\n")
      for k in ["name", "importpath", "commit", "strip_prefix", "type", "build_file_proto_mode"]:
        if k in repo: f.write('        {} = "{}",\n'.format(k, repo[k]))
      for k in ["urls"]:
        if k in repo: f.write('        {} = ["{}"],\n'.format(k, repo[k]))
      f.write("    )\n")

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
