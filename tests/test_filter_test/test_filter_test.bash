#!/bin/bash

# Check that --test_filter can be used to avoid a failing test case.
cd $(dirname "$0")
exec bazel test --test_filter=Pass :go_default_test
