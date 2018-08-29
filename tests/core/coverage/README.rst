coverage functionality
======================

coverage_test_test
------------------

Checks that ``bazel coverage`` on a ``go_test`` produces reasonable output.
Libraries referenced by the test that pass ``--instrumentation_filter`` should
have coverage data. Library excluded with ``--instrumentatiuon_filter`` should
not have coverage data.

coverdata_aspect_test_test
--------------------------

Checks that the ``coverdata`` library is compiled in the same mode as the
test that depends on it.
