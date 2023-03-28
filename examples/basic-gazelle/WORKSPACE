# Load the http ruleset and expose the http_archive rule
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Download rules_go ruleset.
# Bazel makes a https call and downloads the zip file, and then
# checks the sha.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "6b65cb7917b4d1709f9410ffe00ecf3e160edf674b78c54a894471320862184f",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.39.0/rules_go-v0.39.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.39.0/rules_go-v0.39.0.zip",
    ],
)

# Download the bazel_gazelle ruleset.
http_archive(
    name = "bazel_gazelle",
    sha256 = "efbbba6ac1a4fd342d5122cbdfdb82aeb2cf2862e35022c752eaddffada7c3f3",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.27.0/bazel-gazelle-v0.27.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.27.0/bazel-gazelle-v0.27.0.tar.gz",
    ],
)

# Load rules_go ruleset and expose the toolchain and dep rules.
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

# the line below instructs gazelle to save the go dependency definitions
# in the deps.bzl file. Located under '//'.
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

############################################################
# Define your own dependencies here using go_repository.
# Else, dependencies declared by rules_go/gazelle will be used.
# The first declaration of an external repository "wins".
############################################################

# The following line defines the symbol go_dependencies from the deps.bzl file.
# Having the deps in that file, helps the WORKSPACE file stay less
# cluttered.  The library symbol go_dependencies is then added to
# the envionment. The line below calls that function.
load("//:deps.bzl", "go_dependencies")

# The next comment line includes a macro that gazelle reads.
# This macro tells Gazelle to look for repository rules in a macro in a .bzl file,
# and allows Gazelle to find the correct file to maintain the Go dependencies.
# Then the line after the comment calls go_dependencies(), and that funcation
# contains calls to various go_repository rules.

# gazelle:repository_macro deps.bzl%go_dependencies
go_dependencies()

# go_rules_dependencies is a function that registers external dependencies
# needed by the Go rules.
# https://github.com/bazelbuild/rules_go/blob/master/go/dependencies.rst#go_rules_dependencies
go_rules_dependencies()

# The next rule installs the Go toolchains. The Go version is specified
# using the version parameter. This rule will download the Go SDK.
# https://github.com/bazelbuild/rules_go/blob/master/go/toolchains.rst#go_register_toolchains
go_register_toolchains(version = "1.20.2")

# The following call configured the gazelle dependencies, Go environment and Go SDK.
gazelle_dependencies()
