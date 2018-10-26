#!/bin/bash
set -eu -o pipefail

function run_bazel() {
    local out_file="$1"

    "${TEST_SRCDIR}/io_bazel_rules_go/tests/reproducibility/collect_digests" | grep "___MD5___" > "${out_file}"
}

FILE1=$(mktemp)
FILE2=$(mktemp)

echo First run
run_bazel "${FILE1}"

echo Second run
run_bazel "${FILE2}"

echo Diffing runs
diff "${FILE1}" "${FILE2}"
echo Builds are identical!

echo Removing files
rm "${FILE1}" "${FILE2}"
