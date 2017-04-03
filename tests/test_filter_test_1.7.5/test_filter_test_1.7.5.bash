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

# This script checks that --test_filter works with go_test when using
# Go 1.7.5. The generated test driver is different for Go 1.8, due to
# incompatible upstream changes in the testing package.
#
# This is a manual test because it requires downloading Go 1.7.5. This
# should be run manually when go_repositories or generate_test_main change.

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
RULES_DIR=$(cd "$TEST_DIR/../.."; pwd)
WORKSPACE_DIR=$(mktemp -d)
TEST_FILES=(
  BUILD
  test_filter_test.go
)

function cleanup {
  rm -rf "$WORKSPACE_DIR"
}
trap cleanup EXIT

cat >"$WORKSPACE_DIR/WORKSPACE" <<EOF
local_repository(
    name = "io_bazel_rules_go",
    path = "$RULES_DIR",
)
load("@io_bazel_rules_go//go:def.bzl", "go_repositories")
go_repositories(go_version = "1.7.5")
EOF

for file in "${TEST_FILES[@]}"; do
  cp "$TEST_DIR/$file" "$WORKSPACE_DIR/"
done

cd "$WORKSPACE_DIR"
bazel test --test_filter=Pass :go_default_test
