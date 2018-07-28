result="$(${TEST_SRCDIR}/io_bazel_rules_go/tests/examples/executable_name/the_binary)"
expect="The executable ran!"
if [ "$result" != "$expect" ]; then
  echo "error: unexpected bazel exit code: want '$expect', got '$result'" >&2
  exit 1
fi
