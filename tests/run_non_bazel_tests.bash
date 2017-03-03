#!/bin/bash

# This script executes tests that can't be executed through Bazel. For example,
# we may need to test the behavior of the rules when certain flags are passed
# to Bazel on the command line.
#
# This is executed by Travis CI. It will always be executed after the main
# bazel tests. Tests may assume bazel is installed, and dependencies in
# WORKSPACE have been set up.

cd $(dirname "$0")

tests=(
  test_filter_test/test_filter_test.bash
)

result=0
for test in "${tests[@]}"; do
  echo "Running $test" >&2
  $test
  if [ $? -ne 0 ]; then
    echo "Finished $test: FAIL" >&2
    result=1
  else
    echo "Finished $test: PASS" >&2
  fi
done

exit $result
