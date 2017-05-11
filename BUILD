load("//go:def.bzl", "go_prefix")
load("//go/private:lines_sorted_test.bzl", "lines_sorted_test")
load("//proto:go_proto_library.bzl", "go_google_protobuf")
load("//go/private:bzl_format.bzl", "bzl_format_rules")

go_prefix("github.com/bazelbuild/rules_go")

go_google_protobuf()

lines_sorted_test(
    name = "contributors_sorted_test",
    cmd = "grep -v '^#' $< | grep -v '^$$' >$@",
    error_message = "Contributors must be sorted by first name",
    file = "CONTRIBUTORS",
)

lines_sorted_test(
    name = "authors_sorted_test",
    cmd = "grep -v '^#' $< | grep -v '^$$' >$@",
    error_message = "Authors must be sorted by first name",
    file = "AUTHORS",
)

bzl_format_rules()
