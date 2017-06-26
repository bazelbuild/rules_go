load("@io_bazel_rules_go//go:def.bzl", "gazelle", "go_prefix")
load("@io_bazel_rules_go//go/private:lines_sorted_test.bzl", "lines_sorted_test")
load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_google_protobuf")

go_prefix("github.com/bazelbuild/rules_go")

go_google_protobuf()

lines_sorted_test(
    name = "contributors_sorted_test",
    size = "small",
    cmd = "grep -v '^#' $< | grep -v '^$$' >$@",
    error_message = "Contributors must be sorted by first name",
    file = "CONTRIBUTORS",
)

lines_sorted_test(
    name = "authors_sorted_test",
    size = "small",
    cmd = "grep -v '^#' $< | grep -v '^$$' >$@",
    error_message = "Authors must be sorted by first name",
    file = "AUTHORS",
)

# This could be any file, used as an anchor point for the directory in tests
exports_files(["README.md"])

gazelle(
    name = "gazelle",
)
