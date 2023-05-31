# Go with Bzlmod

This document describes how to use rules_go and Gazelle with Bazel's new external dependency subsystem [Bzlmod](https://bazel.build/external/overview#bzlmod), which is meant to replace `WORKSPACE` files eventually.
Usages of rules_go and Gazelle in `BUILD` files are not affected by this; refer to the existing documentation on rules and configuration options for them.

## Setup

Add the following lines to your `MODULE.bazel` file:

```starlark
bazel_dep(name = "rules_go", version = "0.39.1")
bazel_dep(name = "gazelle", version = "0.31.0")
```

The latest versions are always listed on https://registry.bazel.build/.

If you have WORKSPACE dependencies that reference rules_go and/or Gazelle, you can still use the legacy repository names for the two repositories:

```starlark
bazel_dep(name = "rules_go", version = "0.39.1", repo_name = "io_bazel_rules_go")
bazel_dep(name = "gazelle", version = "0.31.0", repo_name = "bazel_gazelle")
```

## Registering Go SDKs

rules_go automatically downloads and registers a recent Go SDK, so unless a particular version is required, no manual steps are required.

To register a particular version of the Go SDK, use the `go_sdk` module extension:

```starlark
go_sdk = use_extension("@rules_go//go:extensions.bzl", "go_sdk")

# Download an SDK for the host OS & architecture.
go_sdk.download(version = "1.20.3")

# Alternately, download an SDK for a fixed OS/architecture, e.g. for remote execution.
go_sdk.download(
    version = "1.20.3",
    goarch = "amd64",
    goos = "linux",
)

# Register the Go SDK installed on the host.
go_sdk.host()
```

You can register multiple Go SDKs and select which one to use on a per-target basis using [`go_cross_binary`](rules.md#go_cross_binary).
The usual rules of [toolchain resolution](https://bazel.build/extending/toolchains#toolchain-resolution) apply, with SDKs registered in the root module taking precedence over those registered in dependencies.

### Using a Go SDK

By default, Go SDK repositories are created with mangled names and are not expected to be referenced directly.

For build actions, toolchain resolution is used to select the appropriate SDK for a given target.
[`go_cross_binary`](rules.md#go_cross_binary) can be used to influence the outcome of the resolution.

The `go` tool of the SDK registered for the host is available via the `@rules_go//go` target.
Prefer running it via this target over running `go` directly to ensure that all developers use the same version.
The `@rules_go//go` target can be used in scripts executed via `bazel run`, but cannot be used in build actions.
Note that `go` command arguments starting with `-` require the use of the double dash separator with `bazel run`:

```sh
bazel run @rules_go//go -- mod tidy -v
```

If you really do need direct access to a Go SDK, you can provide the `name` attribute on the `go_sdk.download` or `go_sdk.host` tag and then bring the repository with that name into scope via `use_repo`.
Note that modules using this attribute cannot be added to registries such as the Bazel Central Registry (BCR).
If you have a use case that would require this, please explain it in an issue.

### Not yet supported

* `go_local_sdk`
* `go_wrap_sdk`
* nogo ([#3529](https://github.com/bazelbuild/rules_go/issues/3529))

## Generating BUILD files

Add the following to your top-level BUILD file:

```starlark
load("@gazelle//:def.bzl", "gazelle")

gazelle(name = "gazelle")
```

If there is no `go.mod` file in the same directory as your top-level BUILD file, also add the following [Gazelle directive](https://github.com/bazelbuild/bazel-gazelle#directives) to that BUILD file to supply Gazelle with your Go module's path:

```starlark
# gazelle:prefix github.com/example/project
```

Then, use `bazel run //:gazelle` to (re-)generate BUILD files.

## External dependencies

External Go dependencies are managed by the `go_deps` module extension provided by Gazelle.
`go_deps` performs [Minimal Version Selection](https://go.dev/ref/mod#minimal-version-selection) on all transitive Go dependencies of all Bazel modules, so compared to the old WORKSPACE setup, every Bazel module only needs to declare its own Go dependencies.
For every major version of a Go module, there will only ever be a single version in the entire build, just as in regular Go module builds.

### Specifying external dependencies

Even though this is not a strict requirement, for interoperability with Go tooling that isn't Bazel-aware, it is recommended to manage Go dependencies via `go.mod`.
The `go_deps` extension parses this file directly, so external tooling such as `gazelle update-repos` is no longer needed.

Register the `go.mod` file with the `go_deps` extension as follows:

```starlark
go_deps = use_extension("@gazelle//:extensions.bzl", "go_deps")
go_deps.from_file(go_mod = "//:go.mod")

# All *direct* Go dependencies of the module have to be listed explicitly.
use_repo(
    go_deps,
    "com_github_gogo_protobuf",
    "com_github_golang_mock",
    "com_github_golang_protobuf",
    "org_golang_x_net",
)
```

Bazel emits a warning if the `use_repo` statement is out of date or missing entirely (requires Bazel 6.2.0 or higher).
The warning contains a `buildozer` command to automatically fix the `MODULE.bazel` file (requires buildozer 6.1.1 or higher).

Alternatively, you can specify a module extension tag to add an individual dependency.
This can be useful for dependencies of generated code that `go mod tidy` would remove. (There is [ongoing work](https://github.com/bazelbuild/bazel-gazelle/pull/1495) to provide a Bazel-aware version of `tidy`.)

```starlark
go_deps.module(
    path = "google.golang.org/grpc",
    sum = "h1:fPVVDxY9w++VjTZsYvXWqEf9Rqar/e+9zYfxKK+W+YU=",
    version = "v1.50.0",
)
```

### Managing `go.mod`

An initial `go.mod` file can be created via

```sh
bazel run @rules_go//go mod init github.com/example/project
```

A dependency can be added via

```sh
bazel run @rules_go//go get golang.org/x/text@v0.3.2
```

### Overrides

The root module can override certain aspects of the dependency resolution performed by the `go_deps` extension.

#### `replace`

[`replace` directives](https://go.dev/ref/mod#go-mod-file-replace) in `go.mod` can be used to replace particular versions of dependencies with other versions or entirely different modules.
At the moment the only supported form is:

```
replace(
    golang.org/x/net v1.2.3 => example.com/fork/net v1.4.5
)
```

#### Gazelle directives

Some external Go modules may require tweaking how Gazelle generates BUILD files for them via [Gazelle directives](https://github.com/bazelbuild/bazel-gazelle#directives).
The `go_deps` extension provides a dedicated `go_deps.gazelle_override` tag for this purpose:

```starlark
go_deps.gazelle_override(
    directives = [
        "gazelle:go_naming_convention go_default_library",
    ],
    path = "github.com/stretchr/testify",
)
```

If you need to use a `gazelle_override` to get a public Go module to build with Bazel, consider contributing the directives to the [public registry for default Gazelle overrides](https://github.com/bazelbuild/bazel-gazelle/blob/master/internal/bzlmod/default_gazelle_overrides.bzl) via a PR.
This will allow you to drop the `gazelle_override` tag and also makes the Go module usable in non-root Bazel modules.

### Not yet supported

* Fetching dependencies from Git repositories or via HTTP
* `go.mod` `replace` directives matching all versions of a module
* `go.mod` `replace` directives referencing local files
* `go.mod` `exclude` directices
