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
  @org_golang_x_net//...
  @org_golang_x_text//...
  @org_golang_x_tools//...
)

excludes=(
  # TODO(#413): External test depends on symbols defined in internal test.
  -@org_golang_x_tools//container/intsets:go_default_xtest

  # TODO(#414): Error compiling test main.
  -@org_golang_x_net//ipv6:go_default_test

  # TODO(#417): several tests fail. Need to investigate and fix.
  -@org_golang_x_net//bpf:go_default_test
  -@org_golang_x_net//html/charset:go_default_test
  -@org_golang_x_net//http2:go_default_test
  -@org_golang_x_net//icmp:go_default_xtest
  -@org_golang_x_text//collate/tools/colcmp:all
  -@org_golang_x_text//encoding/charmap:go_default_test
  -@org_golang_x_text//encoding/japanese:go_default_test
  -@org_golang_x_text//encoding/korean:go_default_test
  -@org_golang_x_text//encoding/simplifiedchinese:go_default_test
  -@org_golang_x_text//encoding/traditionalchinese:go_default_test
  -@org_golang_x_text//encoding/unicode/utf32:go_default_test
  -@org_golang_x_text//encoding/unicode:go_default_test
  -@org_golang_x_tools//cmd/bundle:go_default_test
  -@org_golang_x_tools//cmd/callgraph:go_default_test
  -@org_golang_x_tools//cmd/cover:go_default_xtest
  -@org_golang_x_tools//cmd/fiximports:go_default_test
  -@org_golang_x_tools//cmd/godoc:go_default_xtest
  -@org_golang_x_tools//cmd/guru:go_default_xtest
  -@org_golang_x_tools//cmd/stringer:go_default_test
  -@org_golang_x_tools//go/buildutil:go_default_xtest
  -@org_golang_x_tools//go/callgraph/cha:go_default_xtest
  -@org_golang_x_tools//go/callgraph/rta:go_default_xtest
  -@org_golang_x_tools//go/gccgoexportdata:go_default_xtest
  -@org_golang_x_tools//go/gcexportdata:go_default_xtest
  -@org_golang_x_tools//go/gcimporter15:go_default_test
  -@org_golang_x_tools//go/gcimporter15:go_default_xtest
  -@org_golang_x_tools//go/internal/gccgoimporter:go_default_test
  -@org_golang_x_tools//go/loader:go_default_xtest
  -@org_golang_x_tools//go/pointer:go_default_xtest
  -@org_golang_x_tools//go/ssa/interp:go_default_xtest
  -@org_golang_x_tools//go/ssa/ssautil:go_default_xtest
  -@org_golang_x_tools//go/ssa:go_default_xtest
  -@org_golang_x_tools//refactor/eg:go_default_xtest
  -@org_golang_x_tools//refactor/importgraph:go_default_xtest
  -@org_golang_x_tools//refactor/rename:go_default_test
)

case $(uname) in
  Linux)
    excludes+=(
      # route only supports BSD variants.
      -@org_golang_x_net//route:all
    )
    ;;
esac

bazel_batch_test --keep_going -- "${targets[@]}" "${excludes[@]}"

# TODO(#415): golang.org/x/crypto can't be built because there is a package
# named "ssh/testdata", which gazelle doesn't recurse into.

# TODO(#399): golang.org/x/sys can't be built because there is a package named
# "unix/linux" with multiple packages in ignored files. Gazelle should ignore
# packages that are effectively empty.

# TODO(#409): golang.org/x/net has a package, route, with BSD-only code. Causes
# a build error on linux because go_library ends up empty.

# TODO: golang.org/x/oauth2 has dependency on
# cloud.google.com/go/compute/metadata. Not supported yet.

# TODO: in addition to testing all of the golang.org/x packages can be built
# automatically, we should test a collection of popular libraries.
