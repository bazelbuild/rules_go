workspace(name = "io_bazel_rules_go")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.20.2")

http_archive(
    name = "com_google_protobuf",
    sha256 = "75be42bd736f4df6d702a0e4e4d30de9ee40eac024c4b845d17ae4cc831fe4ae",
    strip_prefix = "protobuf-21.7",
    # latest available in BCR, as of 2022-09-30
    urls = [
        "https://github.com/protocolbuffers/protobuf/archive/v21.7.tar.gz",
        "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v21.7.tar.gz",
    ],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@io_bazel_rules_go//extras:embed_data_deps.bzl", "go_embed_data_dependencies")

go_embed_data_dependencies()

# Used by //tests:buildifier_test.
http_archive(
    name = "com_github_bazelbuild_buildtools",
    sha256 = "ca524d4df8c91838b9e80543832cf54d945e8045f6a2b9db1a1d02eec20e8b8c",
    strip_prefix = "buildtools-6.0.1",
    # latest, as of 2023-03-27
    urls = ["https://github.com/bazelbuild/buildtools/archive/refs/tags/6.0.1.tar.gz"],
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
    name = "bazelci_rules",
    sha256 = "eca21884e6f66a88c358e580fd67a6b148d30ab57b1680f62a96c00f9bc6a07e",
    strip_prefix = "bazelci_rules-1.0.0",
    url = "https://github.com/bazelbuild/continuous-integration/releases/download/rules-1.0.0/bazelci_rules-1.0.0.tar.gz",
)

load("@bazelci_rules//:rbe_repo.bzl", "rbe_preconfig")

# Creates a default toolchain config for RBE.
# Use this as is if you are using the rbe_ubuntu16_04 container,
# otherwise refer to RBE docs.
rbe_preconfig(
    name = "buildkite_config",
    toolchain = "ubuntu1804-bazel-java11",
)

# Needed for tests and tools
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

http_archive(
    name = "bazel_gazelle",
    sha256 = "727f3e4edd96ea20c29e8c2ca9e8d2af724d8c7778e7923a854b2c80952bc405",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
    ],
)

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

go_repository(
    name = "com_github_google_go_github_v36",
    importpath = "github.com/google/go-github/v36",
    sum = "h1:ndCzM616/oijwufI7nBRa+5eZHLldT+4yIB68ib5ogs=",
    version = "v36.0.0",
)

go_repository(
    name = "com_github_google_go_querystring",
    importpath = "github.com/google/go-querystring",
    sum = "h1:AnCroh3fv4ZBgVIf1Iwtovgjaw/GiKJo8M8yD/fhyJ8=",
    version = "v1.1.0",
)

go_repository(
    name = "org_golang_x_mod",
    importpath = "golang.org/x/mod",
    sum = "h1:KENHtAZL2y3NLMYZeHY9DW8HW8V+kQyJsY/V9JlKvCs=",
    version = "v0.9.0",
)

go_repository(
    name = "org_golang_x_sync",
    importpath = "golang.org/x/sync",
    sum = "h1:wsuoTGHzEhffawBOhz5CYhcrV4IdKZbEyZjBMuTp12o=",
    version = "v0.1.0",
)

go_repository(
    name = "org_golang_x_oauth2",
    importpath = "golang.org/x/oauth2",
    sum = "h1:Lh8GPgSKBfWSwFvtuWOfeI3aAAnbXTSutYxJiOJFgIw=",
    version = "v0.6.0",
)

# TODO(sluongng): Gazelle v0.25.0 switched to static dependency resolution which cause
# build files generation in external dependencies to wrongly resolve these repositories.
# We should investigate in Gazelle why this happen and fix it.
# For now, use manual mapping as a workaround.
#
# gazelle:repository go_repository name=org_golang_x_tools   importpath=golang.org/x/tools
# gazelle:repository go_repository name=org_golang_x_text    importpath=golang.org/x/text
# gazelle:repository go_repository name=org_golang_x_xerrors importpath=golang.org/x/xerrors
# gazelle:repository go_repository name=org_golang_x_net     importpath=golang.org/x/net
# gazelle:repository go_repository name=org_golang_x_sys     importpath=golang.org/x/sys
# gazelle:repository go_repository name=org_golang_x_crypto  importpath=golang.org/x/crypto

load("@io_bazel_rules_go//tests/legacy/test_chdir:remote.bzl", "test_chdir_remote")

test_chdir_remote()

load("@io_bazel_rules_go//tests/integration/popular_repos:popular_repos.bzl", "popular_repos")

popular_repos()

load("@io_bazel_rules_go//tests:grpc_repos.bzl", "grpc_dependencies")

grpc_dependencies()

gazelle_dependencies()

local_repository(
    name = "runfiles_remote_test",
    path = "tests/core/runfiles/runfiles_remote_test",
)

# For API doc generation
# This is a dev dependency, users should not need to install it
# so we declare it in the WORKSPACE
http_archive(
    name = "io_bazel_stardoc",
    sha256 = "3fd8fec4ddec3c670bd810904e2e33170bedfe12f90adf943508184be458c8bb",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/stardoc/releases/download/0.5.3/stardoc-0.5.3.tar.gz",
        "https://github.com/bazelbuild/stardoc/releases/download/0.5.3/stardoc-0.5.3.tar.gz",
    ],
)

load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")

stardoc_repositories()

# For testing objc_library interop, users should not need to install it
http_archive(
    name = "build_bazel_apple_support",
    sha256 = "77a121a0f5d4cd88824429464ad2bfb54bdc8a3bccdb4d31a6c846003a3f5e44",
    url = "https://github.com/bazelbuild/apple_support/releases/download/1.4.1/apple_support.1.4.1.tar.gz",
)

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
