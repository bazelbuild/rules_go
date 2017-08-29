load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test", "go_prefix")
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

go_prefix("github.com/bazelbuild/rules_go/tests/coverage")

go_test(
    name = "go_default_test",
    size = "small",
    srcs = ["coverage_test.go"],
    library = ":go_default_library",
    tags = ["manual"],
)

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)

bazel_test(
    name = "coverage",
    check = """
if ! grep -q '^coverage: 50.0% of statements' "bazel-testlogs/go_default_test/test.log"; then
  echo "error: no coverage output found in test log file" >&2
  exit 1
fi
    """,
    command = "coverage",
    target = "//:go_default_test",
)

go_binary(
    name = "bin",
    srcs = ["bin.go"],
    library = ":bin_lib",
)

go_library(
    name = "bin_lib",
    srcs = ["bin_lib.go"],
)

bazel_test(
    name = "bin_coverage",
    check = """
no_tests_found=4
if [ "$result" -ne "$no_tests_found" ]; then
  echo "error: unexpected bazel exit code: want $no_tests_found, got $result" >&2
  exit 1
fi
result=0
""",
    command = "coverage",
    target = "//:bin",
)
