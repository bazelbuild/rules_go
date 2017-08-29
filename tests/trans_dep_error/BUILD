load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_prefix")
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

bazel_test(
    name = "trans_dep_error",
    check = """
if [ "$result" -eq 0 ]; then
  echo "error: build succeeded unexpectedly" >&2
  result=1
else
  result=0
fi
""",
    command = "build",
    target = "//:go_default_library",
)

go_prefix("github.com/bazelbuild/rules_go/tests/trans_dep_error")

go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
    tags = ["manual"],
    deps = [":a"],
)

go_library(
    name = "a",
    srcs = ["a.go"],
    deps = [":b"],
)

go_library(
    name = "b",
    srcs = ["b.go"],
)
