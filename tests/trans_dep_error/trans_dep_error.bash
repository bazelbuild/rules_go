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

# This test verifies that the Go rules report an error if an import of a
# go_library is not satisfied by a direct dependency, even if the import
# is satisfied by a transitive dependency.

set -euo pipefail

TEST_DIR=$(cd $(dirname "$0"); pwd)
source "$TEST_DIR/../non_bazel_tests_common.bash"

cd "$TEST_DIR"
if bazel build :go_default_library; then
  echo "expected build of :go_default_library to fail" >&2
  exit 1
fi
