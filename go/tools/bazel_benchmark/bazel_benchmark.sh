#!/usr/bin/env bash

# Copyright 2018 The Bazel Authors. All rights reserved.
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

rules_go_dir=$(mktemp --directory --tmpdir rules_go.XXXXXX)
function cleanup {
  rm -rf "$rules_go_dir"
}
trap cleanup EXIT

git clone --depth=1 --single-branch --no-tags \
  https://github.com/bazelbuild/rules_go "$rules_go_dir"
cd "$rules_go_dir"
bazel run //go/tools/bazel_benchmark -- -rules_go_dir "$rules_go_dir" "$@"

