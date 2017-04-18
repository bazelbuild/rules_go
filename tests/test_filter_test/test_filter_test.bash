#!/bin/bash

# Check that --test_filter can be used to avoid a failing test case.
cd $(dirname "$0")
source ../non_bazel_tests_common.bash

bazel_test --test_filter=Pass :go_default_test
