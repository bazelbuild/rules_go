workspace(name = "io_bazel_rules_go")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.20.7")

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
    sha256 = "178eba9540a616bda314afa25a91f195758a9fed178eda72e149eb0d20e9b670",
    strip_prefix = "bazel-gazelle-9fe0a3ff751647789690293dcbb3c87ea33b7566",
    urls = [
        "https://github.com/bazelbuild/bazel-gazelle/archive/9fe0a3ff751647789690293dcbb3c87ea33b7566.zip",
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

http_archive(
    name = "googleapis",
    sha256 = "9d1a930e767c93c825398b8f8692eca3fe353b9aaadedfbcf1fca2282c85df88",
    strip_prefix = "googleapis-64926d52febbf298cb82a8f472ade4a3969ba922",
    urls = [
        "https://github.com/googleapis/googleapis/archive/64926d52febbf298cb82a8f472ade4a3969ba922.zip",
    ],
)

go_repository(
    name = "org_golang_google_genproto",
    build_extra_args = ["-exclude=vendor"],
    build_file_generation = "on",
    build_file_proto_mode = "disable_global",
    importpath = "google.golang.org/genproto",
    sum = "h1:S9GbmC1iCgvbLyAokVCwiO6tVIrU9Y7c5oMx1V/ki/Y=",
    version = "v0.0.0-20221024183307-1bc688fe9f3e",
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

load("@googleapis//:repository_rules.bzl", "switched_rules_by_language")

switched_rules_by_language(
    name = "com_google_googleapis_imports",
)

# For testing the compatibility with a hermetic cc toolchain. Users should not have to enable it.
http_archive(
    name = "hermetic_cc_toolchain",
    sha256 = "bd2234acd0837251361be3270d7d3ce599b418be123d902d84762302e31a3014",
    strip_prefix = "hermetic_cc_toolchain-13c904dce0cb9b6d07f0d557e6ce3cf7013a562e",
    urls = ["https://github.com/uber/hermetic_cc_toolchain/archive/13c904dce0cb9b6d07f0d557e6ce3cf7013a562e.zip"],
)

load("@hermetic_cc_toolchain//toolchain:defs.bzl", zig_toolchains = "toolchains")

zig_toolchains(
    host_platform_sha256 = {
        "linux-aarch64": "12be476ed53c219507e77737dbb7f2a77b280760b8acbc6ba2eaaeb42b7d145e",
        "linux-x86_64": "1b1c115c4ccbdc215cc3b07833c7957336d9f5fff816f97e5cafee556a9d8be8",
        "macos-aarch64": "3943612c560dd066fba5698968317a146a0f585f6cdaa1e7c1df86685c7c4eaf",
        "macos-x86_64": "0c89e5d934ecbf9f4d2dea6e3b8dfcc548a3d4184a856178b3db74e361031a2b",
    },
    version = "0.11.0-dev.3886+0c1bfe271",
)
