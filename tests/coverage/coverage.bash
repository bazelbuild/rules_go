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

# This script verifies that some coverage information is included in the log
# for go_test targets run with "bazel coverage". We don't produce reports yet
# or integrate with Bazel, so there's nothing to test in that area yet.

set -euo pipefail

cd $(dirname "$0")
source ../non_bazel_tests_common.bash

bazel_coverage //tests/coverage:go_default_test
if ! grep -q '^coverage: 50.0% of statements' "$RULES_DIR/bazel-testlogs/tests/coverage/go_default_test/test.log"; then
  echo "error: no coverage output found in test log file" >&2
  exit 1
fi
