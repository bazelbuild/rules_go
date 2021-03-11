workspace(name = "io_bazel_rules_go")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies(is_rules_go = True)

go_register_toolchains(version = "1.16.1")

http_archive(
    name = "com_google_protobuf",
    sha256 = "bc3dbf1f09dba1b2eb3f2f70352ee97b9049066c9040ce0c9b67fb3294e91e4b",
    strip_prefix = "protobuf-3.15.5",
    # latest, as of 2021-03-08
    urls = [
        "https://github.com/protocolbuffers/protobuf/archive/v3.15.5.tar.gz",
        "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v3.15.5.tar.gz",
    ],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

go_embed_data_dependencies()

# Used by //tests:buildifier_test.
# Latest release is not compatible with the incompatible bazel flags we use
# in CI, in particular, --incompatible_load_proto_rules_from_bzl.
git_repository(
    name = "com_github_bazelbuild_buildtools",
    commit = "f630fda6c1db92241fee1ff66ca07018b2c7a5f3",  # master as of 2020-02-03
    remote = "https://github.com/bazelbuild/buildtools",
    shallow_since = "1580754619 +0100",
)

# For manual testing against an LLVM toolchain.
# Use --crosstool_top=@llvm_toolchain//:toolchain
http_archive(
    name = "com_grail_bazel_toolchain",
    sha256 = "d312c8e3a19ff843fce3065bb9ff40964401e8525674c842a5724b939cb6e1ac",
    strip_prefix = "bazel-toolchain-0.4.4",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/0.4.4.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "8.0.0",
)

http_archive(
    name = "bazel_toolchains",
    sha256 = "1adf5db506a7e3c465a26988514cfc3971af6d5b3c2218925cd6e71ee443fc3f",
    strip_prefix = "bazel-toolchains-4.0.0",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/releases/download/4.0.0/bazel-toolchains-4.0.0.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/releases/download/4.0.0/bazel-toolchains-4.0.0.tar.gz",
    ],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")

# Creates toolchain configuration for remote execution with BuildKite CI
# for rbe_ubuntu1604
rbe_autoconfig(
    name = "buildkite_config",
)

# Needed for tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

http_archive(
    name = "bazel_gazelle",
    sha256 = "222e49f034ca7a1d1231422cdb67066b885819885c356673cb1f72f748a3c9d4",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.3/bazel-gazelle-v0.22.3.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.3/bazel-gazelle-v0.22.3.tar.gz",
    ],
)

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

load("@io_bazel_rules_go//tests/legacy/test_chdir:remote.bzl", "test_chdir_remote")

test_chdir_remote()

load("@io_bazel_rules_go//tests/integration/popular_repos:popular_repos.bzl", "popular_repos")

popular_repos()

load("@io_bazel_rules_go//tests:grpc_repos.bzl", "grpc_dependencies")

grpc_dependencies()

local_repository(
    name = "runfiles_remote_test",
    path = "tests/core/runfiles/runfiles_remote_test",
)
