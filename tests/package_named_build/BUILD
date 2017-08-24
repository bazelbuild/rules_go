load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

# The following directories are really data not code
# gazelle:exclude local
# gazelle:exclude remote

bazel_test(
    name = "package_named_build",
    command = "test",
    target = "//:go_default_test",
    subdir = "local",
    workspace = """
local_repository(
    name = "remote",
    path = "../remote",
)
""",
    prepare = """
cd $PACKAGE/remote
$BASE/go/tools/gazelle/gazelle/gazelle --go_prefix remote --mode fix --repo_root $PACKAGE/remote
""",
)
