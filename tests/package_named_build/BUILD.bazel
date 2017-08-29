load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test")

# The following directories are really data not code
# gazelle:exclude local
# gazelle:exclude remote

bazel_test(
    name = "package_named_build",
    command = "test",
    prepare = """
cd $PACKAGE/remote
$BASE/go/tools/gazelle/gazelle/gazelle --go_prefix remote --mode fix --repo_root $PACKAGE/remote
""",
    subdir = "local",
    target = "//:go_default_test",
    workspace = """
local_repository(
    name = "remote",
    path = "../remote",
)
""",
)
