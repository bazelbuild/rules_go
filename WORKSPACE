workspace(name = "io_bazel_rules_go")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
load("@io_bazel_rules_go//proto:def.bzl", "proto_register_toolchains")

go_rules_dependencies()

go_register_toolchains()

# Needed for tests
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

load("@io_bazel_rules_go//tests:bazel_tests.bzl", "test_environment")

test_environment()

load("@io_bazel_rules_go//tests/legacy/test_chdir:remote.bzl", "test_chdir_remote")

test_chdir_remote()

load("@io_bazel_rules_go//tests/integration/popular_repos:popular_repos.bzl", "popular_repos")

popular_repos()

# For manual testing against an LLVM toolchain.
# Use --crosstool_top=@llvm_toolchain//:toolchain
http_archive(
    name = "com_grail_bazel_toolchain",
    sha256 = "aafea89b6abe75205418c0d2127252948afe6c7f2287a79b67aab3e0c3676c4f",
    strip_prefix = "bazel-toolchain-d0a5b0af3102c7c607f2cf098421fcdbaeaaaf19",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/d0a5b0af3102c7c607f2cf098421fcdbaeaaaf19.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:configure.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "6.0.0",
)

http_archive(
    name = "bazel_toolchains",
    sha256 = "7938215442cc96b1a16809f4643db14af7d91c3ef1e98d39593bb46862204537",
    strip_prefix = "bazel-toolchains-809c13c3a96966f63c7a43c586cb4e72589184b6",
    urls = [
        "https://github.com/bazelbuild/bazel-toolchains/archive/809c13c3a96966f63c7a43c586cb4e72589184b6.tar.gz",
    ],
)
