load("//go:def.bzl", "go_prefix")
load("//go/private:lines_sorted_test.bzl", "lines_sorted_test")

go_prefix("github.com/bazelbuild/rules_go")

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
