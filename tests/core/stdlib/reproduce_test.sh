#!/usr/bin/env bash
set -eux -o pipefail

function run_bazel() {
    bazel clean --expunge
    bazel test //tests/core/go_binary:all
    find bazel-out/ -name '*.a' | sort | uniq | grep stdlib | xargs shasum > $1
}

FILE1=$(mktemp)
FILE2=$(mktemp)

echo First run
run_bazel ${FILE1}

echo Second run
run_bazel ${FILE2}

echo Diffing runs
diff ${FILE1} ${FILE2}

echo Removing files
rm ${FILE1} ${FILE2}
