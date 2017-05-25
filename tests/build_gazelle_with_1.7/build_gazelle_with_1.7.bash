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

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
source "$TEST_DIR/../non_bazel_tests_common.bash"

WORKSPACE_DIR=$(mktemp -d)

function cleanup {
  rm -rf "$WORKSPACE_DIR"
}
trap cleanup exit

sed -e "s!@@RULES_DIR@@!$RULES_DIR!" <"$TEST_DIR/WORKSPACE.in" >"$WORKSPACE_DIR/WORKSPACE"
cd "$WORKSPACE_DIR"
bazel_batch_build @io_bazel_rules_go//go/tools/gazelle/gazelle
