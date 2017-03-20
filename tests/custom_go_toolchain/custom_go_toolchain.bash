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

# This script tests custom Go toolchains specified with the go_repositories
# rule. It downloads an old version of Go, creates a workspace that references
# it, and verifies that a go_binary can be built in that workspace.
#
# This test is expensive because of the large download, so it is not run as
# part of continuous integration at this time. Run it manually when
# go_repositories changes.

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
RULES_DIR=$(cd "$TEST_DIR/../.."; pwd)

GO_VERSION=1.7.5
WORKSPACE_DIR=$(mktemp -d)
GO_ARCHIVE=$(mktemp)
GO_DIR=$(mktemp -d)

case $(uname) in
Linux)
  OS=linux
  HASH=2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3
  ;;
Darwin)
  OS=darwin
  HASH=2e2a5e0a5c316cf922cf7d59ee5724d49fc35b07a154f6c4196172adfc14b2ca
  ;;
*)
  echo Unknown operating system: $(uname) >&1
  exit 1
esac
URL="https://storage.googleapis.com/golang/go$GO_VERSION.$OS-amd64.tar.gz"

function cleanup {
  rm -rf "$WORKSPACE_DIR" "$GO_ARCHIVE" "$GO_DIR"
}
trap cleanup EXIT

curl "$URL" >"$GO_ARCHIVE"
ACTUAL_HASH=$(shasum -a 256 "$GO_ARCHIVE" | awk '{print $1}')
if [ "$ACTUAL_HASH" != "$HASH" ]; then
  echo "error: downloaded archive does not match SHA-256 sum" >&1
  echo "  got:  $ACTUAL_HASH" >&1
  echo "  want: $HASH" >&1
  exit 1
fi
tar -xz --directory="$GO_DIR" --file="$GO_ARCHIVE" --strip-components=1 go

cat >"$WORKSPACE_DIR/WORKSPACE" <<EOF
new_local_repository(
    name = "local_go",
    path = "$GO_DIR",
    build_file_content = "",
)
local_repository(
    name = "io_bazel_rules_go",
    path = "$RULES_DIR",
)
load("@io_bazel_rules_go//go:def.bzl", "go_repositories")
go_repositories(go_$OS = "@local_go")
EOF

cp "$TEST_DIR"/BUILD "$WORKSPACE_DIR"
cp "$TEST_DIR"/print_version.go "$WORKSPACE_DIR"
pushd "$WORKSPACE_DIR"
ACTUAL_VERSION=$(bazel \
                   run \
                   --genrule_strategy=standalone \
                   --spawn_strategy=standalone \
                   //:print_version)
popd
if [ "$ACTUAL_VERSION" != "go$GO_VERSION" ]; then
  echo "bad version; got $ACTUAL_VERSION, want $GO_VERSION" >&1
  exit 1
fi
