#!/bin/bash

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

# This test ensures we can build and test popular Go repositories without
# manually writing BUILD files. It sets up a WORKSPACE file with several
# new_go_repository rules, then builds everything in each repository.

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
source "$TEST_DIR/../non_bazel_tests_common.bash"
WORKSPACE_DIR=$(mktemp -d)

function cleanup {
  rm -rf "$WORKSPACE_DIR"
}
trap cleanup EXIT

sed -e "s|@@RULES_DIR@@|$RULES_DIR|" \
  <"$TEST_DIR/WORKSPACE.in" >"$WORKSPACE_DIR/WORKSPACE"
cd "$WORKSPACE_DIR"
touch BUILD

targets=(
  @org_golang_x_crypto//...
  @org_golang_x_net//...
  @org_golang_x_sys//...
  @org_golang_x_text//...
  @org_golang_x_tools//...
  @com_github_mattn_go_sqlite3//...
)

excludes=(
  # TODO(#413): External test depends on symbols defined in internal test.
  -@org_golang_x_tools//container/intsets:go_default_xtest
  -@org_golang_x_sys//unix:go_default_xtest

  # TODO(#359): cgo library has platform-specific sources and is empty on
  # some platforms, causing an error.
  -@org_golang_x_text//collate/tools/colcmp:all

  # TODO: tests cannot access files in testdata directories.
  -@org_golang_x_net//bpf:go_default_test
  -@org_golang_x_net//html/charset:go_default_test
  -@org_golang_x_net//http2:go_default_test
  -@org_golang_x_text//encoding/japanese:go_default_test
  -@org_golang_x_text//encoding/korean:go_default_test
  -@org_golang_x_text//encoding/charmap:go_default_test
  -@org_golang_x_text//encoding/simplifiedchinese:go_default_test
  -@org_golang_x_text//encoding/traditionalchinese:go_default_test
  -@org_golang_x_text//encoding/unicode/utf32:go_default_test
  -@org_golang_x_text//encoding/unicode:go_default_test
  -@org_golang_x_tools//cmd/bundle:go_default_test
  -@org_golang_x_tools//cmd/callgraph:go_default_test
  -@org_golang_x_tools//cmd/cover:go_default_xtest
  -@org_golang_x_tools//cmd/guru:go_default_xtest
  -@org_golang_x_tools//cmd/stringer:go_default_test
  -@org_golang_x_tools//go/buildutil:go_default_xtest
  -@org_golang_x_tools//go/callgraph/cha:go_default_xtest
  -@org_golang_x_tools//go/callgraph/rta:go_default_xtest
  -@org_golang_x_tools//go/gccgoexportdata:go_default_xtest
  -@org_golang_x_tools//go/gcexportdata:go_default_xtest
  -@org_golang_x_tools//go/gcimporter15:go_default_test
  -@org_golang_x_tools//go/internal/gccgoimporter:go_default_test
  -@org_golang_x_tools//go/loader:go_default_xtest
  -@org_golang_x_tools//go/pointer:go_default_xtest
  -@org_golang_x_tools//go/ssa/interp:go_default_xtest
  -@org_golang_x_tools//go/ssa/ssautil:go_default_xtest
  -@org_golang_x_tools//go/ssa:go_default_xtest
  -@org_golang_x_tools//refactor/eg:go_default_xtest
  -@org_golang_x_crypto//ed25519:go_default_test
  -@org_golang_x_crypto//sha3:go_default_test
  -@org_golang_x_crypto//ssh/agent:go_default_test

  # TODO(#546): deps don't get propagated from cgo_library through go_library
  # to go_test.
  -@com_github_mattn_go_sqlite3//:go_default_test

  # TODO(#417): several tests fail. Need to investigate and fix.
  -@org_golang_x_tools//cmd/godoc:go_default_xtest
  -@org_golang_x_tools//go/gcimporter15:go_default_xtest
  -@org_golang_x_tools//refactor/importgraph:go_default_xtest
  -@org_golang_x_tools//refactor/rename:go_default_test

  # ssh needs to accept incoming connections. Not allowed in CI or on Darwin.
  -@org_golang_x_crypto//ssh:go_default_test
  -@org_golang_x_crypto//ssh/test:go_default_test

  # icmp requires adjusting kernel options.
  -@org_golang_x_net//icmp:go_default_xtest

  # fiximports requires working GOROOT, not present in CI.
  -@org_golang_x_tools//cmd/fiximports:go_default_test

  # tools tests have unbuildable Go code in testdata directories.
  -@org_golang_x_tools//cmd/bundle/testdata/...
  -@org_golang_x_tools//cmd/callgraph/testdata/...
  -@org_golang_x_tools//cmd/cover/testdata/...
  -@org_golang_x_tools//cmd/fiximports/testdata/...
  -@org_golang_x_tools//cmd/goyacc/testdata/...
  -@org_golang_x_tools//cmd/guru/testdata/...
  -@org_golang_x_tools//cmd/stringer/testdata/...
  -@org_golang_x_tools//go/gcimporter15/testdata/...
  -@org_golang_x_tools//go/loader/testdata/...
  -@org_golang_x_tools//go/pointer/testdata/...
)

case $(uname) in
  Linux)
    excludes+=(
      # route only supports BSD variants.
      -@org_golang_x_net//route:all
      # windows only supports windows.
      -@org_golang_x_sys//windows/...
    )
    ;;

  Darwin)
    excludes+=(
      # windows only supports windows.
      -@org_golang_x_sys//windows/...
    )
    ;;
esac

bazel_batch_test --keep_going -- "${targets[@]}" "${excludes[@]}"

# TODO(#526): github.com/mattn/go-sqlite3 can't be built as an external
# dependency due to an include issue with cgo.

# TODO: golang.org/x/oauth2 has dependency on
# cloud.google.com/go/compute/metadata. Not supported yet.

# TODO: in addition to testing all of the golang.org/x packages can be built
# automatically, we should test a collection of popular libraries.
