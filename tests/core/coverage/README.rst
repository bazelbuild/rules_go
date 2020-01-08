.. _#2127: https://github.com/bazelbuild/rules_go/issues/2127

coverage functionality
======================

coverage_test
-------------

Checks that ``bazel coverage`` on a ``go_test`` produces reasonable output.
Libraries referenced by the test that pass ``--instrumentation_filter`` should
have coverage data. Library excluded with ``--instrumentatiuon_filter`` should
not have coverage data.

binary_coverage_test
--------------------

Checks that ``bazel build --collect_code_coverage`` can instrument a
``go_binary``. ``bazel coverage`` should also work, though it should fail
with status 4 since the binary is not a test.

This functionality isn't really complete. The generate test main package
gathers and writes coverage data, and that's not present. This is just
a regression test for a link error (`#2127`_).
