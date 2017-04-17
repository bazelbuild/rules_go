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

# This script tests that new_go_repository can be used to build a
# package named "build" without explicitly specifying
# "build_file_name". In #144, Gazelle would fail on case insensitive
# file systems because "build" looks the same as "BUILD". In
# new_go_repository, Gazelle should name files "BUILD.bazel" by
# default.

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
RULES_DIR=$(cd "$TEST_DIR/../.."; pwd)
WORKSPACE_DIR=$(mktemp -d)

function cleanup {
  rm -rf "$WORKSPACE_DIR"
}
trap cleanup EXIT

cp -r "$TEST_DIR"/* "$WORKSPACE_DIR"

cd "$WORKSPACE_DIR/remote"
git init
git add -A .
git commit -m 'initial commit'
git tag 1.0

cd "$WORKSPACE_DIR/local"
sed \
  -e "s|@@RULES_DIR@@|$RULES_DIR|" \
  -e "s|@@WORKSPACE_DIR@@|$WORKSPACE_DIR|" \
  <WORKSPACE.in >WORKSPACE
bazel test \
  --genrule_strategy=standalone \
  --spawn_strategy=standalone \
  //:go_default_test
