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

export RULES_DIR=$(cd $(dirname "${BASH_SOURCE[0]}")/..; pwd)
export BAZELRC=$RULES_DIR/.test-bazelrc
export BAZEL_BUILD_OPTS="--experimental_repository_cache=$HOME/.bazel_repository_cache"

function bazel_build {
  bazel --bazelrc="$BAZELRC" build $BAZEL_BUILD_OPTS "$@"
}
function bazel_batch_build {
  bazel --bazelrc="$BAZELRC" --batch build $BAZEL_BUILD_OPTS "$@"
}
function bazel_test {
  bazel --bazelrc="$BAZELRC" test $BAZEL_BUILD_OPTS "$@"
}
function bazel_batch_test {
  bazel --bazelrc="$BAZELRC" --batch test $BAZEL_BUILD_OPTS "$@"
}
function bazel_coverage {
  bazel --bazelrc="$BAZELRC" coverage $BAZEL_BUILD_OPTS "$@"
}
function bazel_batch_coverage {
  bazel --bazelrc="$BAZELRC" --batch coverage $BAZEL_BUILD_OPTS "$@"
}
function bazel_run {
  bazel --bazelrc="$BAZELRC" run $BAZEL_BUILD_OPTS "$@"
}
function bazel_batch_run {
  bazel --bazelrc="$BAZELRC" --batch run $BAZEL_BUILD_OPTS "$@"
}
export -f bazel_build bazel_test bazel_run
export -f bazel_batch_build bazel_batch_test bazel_batch_run
