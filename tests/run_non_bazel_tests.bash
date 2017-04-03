#!/bin/bash

# This script executes tests that can't be executed through Bazel. For example,
# we may need to test the behavior of the rules when certain flags are passed
# to Bazel on the command line.
#
# This is executed by Travis CI. It will always be executed after the main
# bazel tests. Tests may assume bazel is installed, and dependencies in
# WORKSPACE have been set up.

cd $(dirname "$0")

prefix=">>>>>>"

tests=(
  gc_opts_unsafe/gc_opts_unsafe.bash
  test_filter_test/test_filter_test.bash
)

# Manual tests are not executed as part of CI.
manual_tests=(
  custom_go_toolchain/custom_go_toolchain.bash
  test_filter_test_1.7.5/test_filter_test_1.7.5.bash
)
if [ "$1" == "manual" ]; then
  tests+=("${manual_tests[@]}")
fi

passing_tests=()
failing_tests=()

for test in "${tests[@]}"; do
  echo "$prefix Running $test" >&2
  $test
  if [ $? -ne 0 ]; then
    echo "$prefix Finished $test: FAIL" >&2
    failing_tests+=("$test")
  else
    echo "$prefix Finished $test: PASS" >&2
    passing_tests+=("$test")
  fi
done

echo
echo "$prefix Executed ${#tests[@]} tests: ${#passing_tests[@]} passed, ${#failing_tests[@]} failed"

[ ${#failing_tests[@]} -eq 0 ]
