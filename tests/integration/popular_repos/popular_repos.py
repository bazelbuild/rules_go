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
            "ssh/agent:agent_test",
            "ssh:ssh_test",
            "ssh/test:test_test",
        ],
    ),

    dict(
        name = "org_golang_x_net",
        importpath = "golang.org/x/net",
        commit = "57efc9c3d9f91fb3277f8da1cff370539c4d3dc5",
        excludes = [
            "bpf:bpf_test", # Needs testdata directory
            "html/charset:charset_test", # Needs testdata directory
            "http2:http2_test", # Needs testdata directory
            "icmp:icmp_test", # icmp requires adjusting kernel options.
            "nettest:nettest_test", #
            "lif:lif_test",
        ],
        darwin_tests = [
            "route:route_test", # Not supported on linux
        ]
    ),

    dict(
        name = "org_golang_x_sys",
        importpath = "golang.org/x/sys",
        commit = "acbc56fc7007d2a01796d5bde54f39e3b3e95945",
    ),

    dict(
        name = "org_golang_x_text",
        importpath = "golang.org/x/text",
        commit = "a9a820217f98f7c8a207ec1e45a874e1fe12c478",
        excludes = [
            "encoding/japanese:japanese_test", # Needs testdata directory
            "encoding/korean:korean_test", # Needs testdata directory
            "encoding/charmap:charmap_test", # Needs testdata directory
            "encoding/simplifiedchinese:simplifiedchinese_test", # Needs testdata directory
            "encoding/traditionalchinese:traditionalchinese_test", # Needs testdata directory
            "encoding/unicode/utf32:utf32_test", # Needs testdata directory
            "encoding/unicode:unicode_test", # Needs testdata directory
        ],
    ),

    dict(
        name = "org_golang_x_tools",
        importpath = "golang.org/x/tools",
        commit = "11eff242d136374289f76e9313c76e9312391172",
        excludes = [
            "blog:blog_test", # Needs goldmark
            "cmd/bundle:bundle_test", # Needs testdata directory
            "cmd/callgraph/testdata/src/pkg:pkg_test", # is testdata
            "cmd/callgraph:callgraph_test", # Needs testdata directory
            "cmd/cover:cover_test", # Needs testdata directory
            "cmd/fiximports:fiximports_test", # requires working GOROOT, not present in CI.
            "cmd/godoc:godoc_test", # TODO(#417)
            "cmd/gorename:gorename_test", # TODO(#417)
            "cmd/guru/testdata/src/referrers:referrers_test", # Not a real test
            "cmd/guru:guru_test", # Needs testdata directory
            "cmd/stringer:stringer_test", # Needs testdata directory
            "container/intsets:intsets_test", # TODO(#413): External test depends on symbols defined in internal test.
            "go/analysis/analysistest:analysistest_test", # requires build cache
            "go/analysis/internal/checker:checker_test", # loads test package with go/packages, which probably needs go list
            "go/analysis/internal/facts:facts_test", # loads test package with go/packages, which probably needs go list
            "go/analysis/multichecker:multichecker_test", # requires go vet
            "go/analysis/passes/asmdecl:asmdecl_test", # Needs testdata directory
            "go/analysis/passes/assign:assign_test", # Needs testdata directory
            "go/analysis/passes/atomic:atomic_test", # Needs testdata directory
            "go/analysis/passes/atomicalign:atomicalign_test", # requires go list
            "go/analysis/passes/bools:bools_test", # Needs testdata directory
            "go/analysis/passes/buildssa:buildssa_test", # Needs testdata directory
            "go/analysis/passes/buildtag:buildtag_test", # Needs testdata directory
            "go/analysis/passes/cgocall:cgocall_test", # Needs testdata directory
            "go/analysis/passes/composite:composite_test", # Needs testdata directory
            "go/analysis/passes/copylock:copylock_test", # Needs testdata directory
            "go/analysis/passes/ctrlflow:ctrlflow_test", # Needs testdata directory
            "go/analysis/passes/deepequalerrors:deepequalerrors_test", # requires go list
            "go/analysis/passes/errorsas:errorsas_test", # requires go list and testdata
            "go/analysis/passes/findcall:findcall_test", # requires build cache
            "go/analysis/passes/httpresponse:httpresponse_test", # Needs testdata directory
            "go/analysis/passes/ifaceassert:ifaceassert_test", # Needs GOROOT
            "go/analysis/passes/loopclosure:loopclosure_test", # Needs testdata directory
            "go/analysis/passes/lostcancel:lostcancel_test", # Needs testdata directory
            "go/analysis/passes/nilfunc:nilfunc_test", # Needs testdata directory
            "go/analysis/passes/nilness:nilness_test", # Needs testdata directory
            "go/analysis/passes/pkgfact:pkgfact_test", # requires go list
            "go/analysis/passes/printf:printf_test", # Needs testdata directory
            "go/analysis/passes/shadow:shadow_test", # Needs testdata directory
            "go/analysis/passes/shift:shift_test", # Needs testdata directory
            "go/analysis/passes/sortslice:sortslice_test", # Needs 'go list'
            "go/analysis/passes/stdmethods:stdmethods_test", # Needs testdata directory
            "go/analysis/passes/stringintconv:stringintconv_test", # Needs 'go list'
            "go/analysis/passes/structtag:structtag_test", # Needs testdata directory
            "go/analysis/passes/testinggoroutine:testinggoroutine_test", # Need 'go env'
            "go/analysis/passes/tests/testdata/src/a:a_test", # Not a real test
            "go/analysis/passes/tests/testdata/src/b_x_test:b_x_test_test", # Not a real test
            "go/analysis/passes/tests/testdata/src/divergent:divergent_test", # Not a real test
            "go/analysis/passes/tests:tests_test", # Needs testdata directory
            "go/analysis/passes/unmarshal:unmarshal_test", # Needs go list
            "go/analysis/passes/unreachable:unreachable_test", # Needs testdata directory
            "go/analysis/passes/unsafeptr:unsafeptr_test", # Needs testdata directory
            "go/analysis/passes/unusedresult:unusedresult_test", # Needs testdata directory
            "go/analysis/unitchecker:unitchecker_test", # requires go vet
            "go/ast/inspector:inspector_test", # requires GOROOT and GOPATH
            "go/buildutil:buildutil_test", # Needs testdata directory
            "go/callgraph/cha:cha_test", # Needs testdata directory
            "go/callgraph/rta:rta_test", # Needs testdata directory
            "go/expect:expect_test", # Needs testdata directory
            "go/gccgoexportdata:gccgoexportdata_test", # Needs testdata directory
            "go/gcexportdata:gcexportdata_test", # Needs testdata directory
            "go/internal/gccgoimporter:gccgoimporter_test", # Needs testdata directory
            "go/internal/gcimporter:gcimporter_test", # Needs testdata directory
            "go/loader:loader_test", # Needs testdata directory
            "go/packages/packagestest/testdata/groups/two/primarymod/expect:expect_test", # Is testdata
            "go/packages/packagestest/testdata:testdata_test", # Is testdata
            "go/packages/packagestest:packagestest_test", # requires build cache
            "go/packages:packages_test", # Hah!
            "go/pointer:pointer_test", # Needs testdata directory
            "go/ssa/interp:interp_test", # Needs testdata directory
            "go/ssa/ssautil:ssautil_test", # Needs testdata directory
            "go/ssa:ssa_test", # Needs testdata directory
            "go/types/typeutil:typeutil_test", # requires GOROOT
            "godoc/static:static_test", # requires data files
            "godoc/vfs/zipfs:zipfs_test", # requires GOROOT
            "godoc:godoc_test", # requires GOROOT and GOPATH
            "internal/apidiff:apidiff_test", # Needs testdata directory
            "internal/gocommand:gocommand_test", # Needs go tool
            "internal/imports:imports_test", # Needs testdata directory
            "internal/lsp/analysis/fillreturns:fillreturns_test", # Needs go tool
            "internal/lsp/analysis/fillstruct:fillstruct_test", # Needs go tool
            "internal/lsp/analysis/nonewvars:nonewvars_test", # Needs GOROOT
            "internal/lsp/analysis/noresultvalues:noresultvalues_test", # Needs GOROOT
            "internal/lsp/analysis/simplifycompositelit:simplifycompositelit_test", # Needs go tool
            "internal/lsp/analysis/simplifyrange:simplifyrange_test", # Needs GOROOT
            "internal/lsp/analysis/simplifyslice:simplifyslice_test", # Needs GOROOT
            "internal/lsp/analysis/undeclaredname:undeclaredname_test", # Needs GOROOT
            "internal/lsp/analysis/unusedparams:unusedparams_test", # Needs go tool
            "internal/lsp/cache:cache_test", # has additional deps
            "internal/lsp/cmd:cmd_test", # panics?
            "internal/lsp/diff/difftest:difftest_test", # has additional deps
            "internal/lsp/diff/myers:myers_test", # has additional deps
            "internal/lsp/diff:diff_test", # has additional deps
            "internal/lsp/fake:fake_test", # has additional deps
            "internal/lsp/fuzzy:fuzzy_test", # has additional deps
            "internal/lsp/lsprpc:lsprpc_test", # has additional deps
            "internal/lsp/mod:mod_test", # has additional deps
            "internal/lsp/regtest:regtest_test", # has additional deps
            "internal/lsp/snippet:snippet_test", # has additional deps
            "internal/lsp/source:source_test", # Needs testdata directory
            "internal/lsp/testdata/lsp/primarymod/analyzer:analyzer_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/codelens:codelens_test", # Is testdata
            "internal/lsp/testdata/lsp/primarymod/godef/a:a_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/implementation/other:other_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/references:references_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/rename/testy:testy_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/signature:signature_test", # Is testdata
            "internal/lsp/testdata/lsp/primarymod/testy:testy_test", # not a real test
            "internal/lsp/testdata/lsp/primarymod/unimported:unimported_test", # not a real test
            "internal/lsp:lsp_test", # Needs testdata directory
            "present:present_test", # Needs goldmark
            "refactor/eg:eg_test", # Needs testdata directory
            "refactor/importgraph:importgraph_test", # TODO(#417)
            "refactor/rename:rename_test", # TODO(#417)
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

    dict(
        name = "org_golang_x_mod",
        importpath = "golang.org/x/mod",
        commit = "c0d644d00ab849f4506f17a98a5740bf0feff020",
        excludes = [
            "sumdb/tlog:tlog_test", # Needs network, not available on RBE
            "zip:zip_test", # Needs vcs tools, not available on RBE
        ],            
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
