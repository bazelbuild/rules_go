# Go rules for [Bazel](https://bazel.build/)

Bazel 0.5.4 | Bazel HEAD
:---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_go.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_go) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=PR/rules_go)](http://ci.bazel.io/view/Bazel%20bootstrap%20and%20maintenance/job/PR/job/rules_go/)

## Announcements

* **September 13, 2017** Release
[0.5.5](https://github.com/bazelbuild/rules_go/releases/tag/0.5.5) is now
available. This is a bug fix release on top of 0.5.4 that removes the sha256
from some of our dependencies, since it changed upstream.
* **August 28, 2017** Release
[0.5.4](https://github.com/bazelbuild/rules_go/releases/tag/0.5.4) is
now available!  This will be the last stable tag before requiring Bazel 0.5.4 and toolchains support.
* **August 9, 2017** Release
[0.5.3](https://github.com/bazelbuild/rules_go/releases/tag/0.5.3) is
now available!

## Contents

* [Overview](#overview)
* [Setup](#setup)
  * [Generating build files](#generating-build-files)
  * [Writing build files by hand](#writing-build-files-by-hand)
* [Build modes](#build-modes)
* [FAQ](#faq)
* [Repository rules](#repository-rules)
  * [go_rules_dependencies](#go_rules_dependencies)
  * [go_register_toolchains](#go_register_toolchains)
  * [go_repository](#go_repository)
  * [new_go_repository](#new_go_repository)
* [Build rules](#build-rules)
  * [go_prefix](#go_prefix)
  * [go_library](#go_library)
  * [cgo_library](#cgo_library)
  * [go_binary](#go_binary)
  * [go_test](#go_test)
  * [go_proto_library](#go_proto_library)
  * [go_embed_data](#go_embed_data)

## Overview

The rules are in the alpha stage of development. They support:

* libraries
* binaries
* tests
* vendoring
* cgo
* cross compilation
* auto generating BUILD files via [gazelle](go/tools/gazelle/README.md)
* protocol buffers (via extension //proto:go_proto_library.bzl)

They currently do not support (in order of importance):

* bazel-style auto generating BUILD (where the library name is other than
  go_default_library)
* C/C++ interoperation except cgo (swig etc.)
* coverage
* test sharding

**Note:** The latest version of these rules (0.5.5) require Bazel ≥ 0.5.2 to
  work.

The `master` branch is only guaranteed to work with the latest version of Bazel.

## Setup

* Create a file at the top of your repository named `WORKSPACE`, and add one
  of the following snippets, verbatim. This will let Bazel fetch necessary
  dependencies from this repository and a few others.
  If you're using the latest stable release you can use the following contents:

    ```bzl
    http_archive(
        name = "io_bazel_rules_go",
        url = "https://github.com/bazelbuild/rules_go/releases/download/0.5.5/rules_go-0.5.5.tar.gz",
        sha256 = "ca58b0b856dc95473b93f2228ab117913b82a6617fc0deabd107346e3981522a",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_repositories")

    go_repositories()
    ```

  If you're using rules_go at or near the HEAD of master, you can use the
  following contents (optionally replacing the commit with something newer):

    ```bzl
    git_repository(
        name = "io_bazel_rules_go",
        remote = "https://github.com/bazelbuild/rules_go.git",
        commit = "d8d73c918ed7b59a5584e0cab4f5274d2f91faab",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()
    go_register_toolchains()
    ```

  You can add more external dependencies to this file later (see
  [go_repository](#go_repository) below).

* Add a file named `BUILD.bazel` or `BUILD` in the root directory of your
  project. In general, you need one of these files in every directory
  with Go code, but you need one in the root directory even if your project
  doesn't have any Go code there.

* Decide on a *prefix* for your project, e.g., `github.com/example/project`.
  This must be a prefix of the import paths for libraries in your project. It
  should generally be the repository URL. Bazel will use this prefix to convert
  between import paths and labels in build files.

* If your project can be built with `go build`, you can
  [generate your build files](#generating-build-files) using Gazelle. If your
  project isn't compatible with `go build` or if you prefer not to use Gazelle,
  you can [write build files by hand](#writing-build-files-by-hand).

### Generating build files

If your project can be built with `go build`, you can generate and update your
build files automatically using Gazelle, a tool included in this repository.
See the [Gazelle README](go/tools/gazelle/README.md) for more information.

* Add the code below to the `BUILD.bazel` file in your repository's
  root directory. Replace the `prefix` string with the prefix you chose for
  your project earlier.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "gazelle")

gazelle(
    name = "gazelle",
    prefix = "github.com/example/project",
)
```

* If your project uses vendoring, add `external = "vendored",` below the
  `prefix` line.

* After adding the `gazelle` rule, run the command below:

```bzl
bazel run //:gazelle
```

  This will generate a `BUILD.bazel` file for each Go package in your
  repository.  You can run the same command in the future to update existing
  build files with new source files, dependencies, and options.

### Writing build files by hand

If your project doesn't follow `go build` conventions or you prefer not to use
Gazelle, you can write build files by hand.

* In each directory that contains Go code, create a file named `BUILD.bazel`
  or `BUILD` (Bazel recognizes both names).

* Add a `load` statement at the top of the file for the rules you use.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
```

* For each library, add a [`go_library`](#go_library) rule like the one below.
  Source files are listed in `srcs`. Other packages you import are listed in
  `deps` using
  [Bazel labels](https://docs.bazel.build/versions/master/build-ref.html#labels)
  that refer to other `go_library` rules. The library's import path should
  be specified with `importpath`.

```bzl
go_library(
    name = "go_default_library",
    srcs = [
        "foo.go",
        "bar.go",
    ],
    deps = [
        "//tools:go_default_library",
        "@org_golang_x_utils//stuff:go_default_library",
    ],
    importpath = "github.com/example/project/foo",
    visibility = ["//visibility:public"],
)
```

* For each test, add a [`go_test`](#go_test) rule like either of the ones below.
  You'll need separate `go_test` rules for internal and external tests.

```bzl
# Internal test
go_test(
    name = "go_default_test",
    srcs = ["foo_test.go"],
    importpath = "github.com/example/project/foo",
    library = ":go_default_library",
)

# External test
go_test(
    name = "go_default_xtest",
    srcs = ["bar_test.go"],
    deps = [":go_default_library"],
    importpath = "github.com/example/project/foo",
)
```

* For each binary, add a [`go_binary`](#go_binary) rule like the one below.

```bzl
go_binary(
    name = "foo",
    srcs = ["main.go"],
    deps = [":go_default_library"],
    importpath = "github.com/example/project/foo",
)
```

* For instructions on how to depend on external libraries,
  see [Vendoring.md](Vendoring.md).

## Build modes

### Building static binaries

You can build binaries in static linking mode using
```
bazel build --output_groups=static //:my_binary
```

You can depend on static binaries (e.g., for packaging) using `filegroup`:

```bzl
go_binary(
    name = "foo",
    srcs = ["foo.go"],
)

filegroup(
    name = "foo_static",
    srcs = [":foo"],
    output_group = "static",
)
```

### Using the race detector

You can run tests with the race detector enabled using
```
bazel test --features=race //...
```

You can build binaries with the race detector enabled using
```
bazel build --output_groups=race //...
```

The difference is necessary because the rules for binaries can produce both
race and non-race versions, but tools used during the build should always be
built in the non-race configuration. `--output_groups` is needed to select
the configuration of the final binary only. For tests, only one executable
can be tested, and `--features` is needed to select the race configuration.

## FAQ

### Can I still use the `go` tool?

Yes, this setup was deliberately chosen to be compatible with `go build`.
Make sure your project appears in `GOPATH`, and it should work.

Note that `go build` won't be aware of dependencies listed in `WORKSPACE`, so
these will be downloaded into `GOPATH`. You may also need to check in generated
files.

### What's up with the `go_default_library` name?

This was used to keep import paths consistent in libraries that can be built
with `go build` before the `importpath` attribute was available.

In order to compile and link correctly, the Go rules need to be able to
translate Bazel labels to Go import paths. Libraries that don't set the
`importpath` attribute explicitly have an implicit dependency on `//:go_prefix`,
a special rule that specifies an import path prefix. The import path is
the prefix concatenated with the Bazel package and target name. For example,
if your prefix was `github.com/example/project`, and your library was
`//foo/bar:bar`, the Go rules would decide the import path was
`github.com/example/project/foo/bar/bar`. The stutter at the end is incompatible
with `go build`, so if the label name is `go_default_library`, the import path
is just the prefix concatenated with the package name. So if your library is
`//foo/bar:go_default_library`, the import path is
`github.com/example/project/foo/bar`.

We are working on deprecating `go_prefix` and making `importpath` mandatory (see
[#721](https://github.com/bazelbuild/rules_go/issues/721)). When this work is
complete, the `go_default_library` name won't be needed. We may decide to stop
using this name in the future (see
[#265](https://github.com/bazelbuild/rules_go/issues/265)).

## Repository rules

### `go_rules_dependencies`

``` bzl
go_rules_dependencies()
```

Adds Go-related external dependencies to the WORKSPACE, including the Go
toolchain and standard library. All the other workspace rules and build rules
assume that this rule is placed in the WORKSPACE.
When [nested workspaces](https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html) arrive this will be redundant.

### `go_register_toolchains`

``` bzl
go_register_toolchains(go_version)
```

Installs the Go toolchains. If `go_version` is specified, it sets the SDK version to use (for example, `"1.8.2"`). By default, the latest SDK will be used.


### `go_repository`

```bzl
go_repository(name, importpath, commit, tag, vcs, remote, urls, strip_prefix, type, sha256, build_file_name, build_file_generation, build_tags)
```

Fetches a remote repository of a Go project, and generates `BUILD.bazel` files
if they are not already present. In vcs mode, it recognizes importpath
redirection.

`importpath` must always be specified. This is used as the root import path
for libraries in the repository.

If the repository should be fetched using a VCS, either `commit` or `tag`
must be specified. `remote` and `vcs` may be specified if they can't be
inferred from `importpath` using the
[normal go logic](https://golang.org/cmd/go/#hdr-Remote_import_paths).

If the repository should be fetched using source archives, `urls` and `sha256`
must be specified. `strip_prefix` and `type` may be specified to control how
the archives are unpacked.

`build_file_name`, `build_file_generation`, and `build_tags` may be used to
control how BUILD.bazel files are generated. By default, Gazelle will generate
BUILD.bazel files if they are not already present.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>String, required</code>
        <p>A unique name for this external dependency.</p>
      </td>
    </tr>
    <tr>
      <td><code>importpath</code></td>
      <td>
        <code>String, required</code>
        <p>The root import path for libraries in the repository.</p>
      </td>
    </tr>
    <tr>
      <td><code>commit</code></td>
      <td>
        <code>String, optional</code>
        <p>The commit hash to checkout in the repository.<br>
        Exactly one of <code>commit</code> or <code>tag</code> must
        be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <code>String, optional</code>
        <p>The tag to checkout in the repository.<br>
        Exactly one of <code>commit</code> or <code>tag</code> must
        be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>vcs</code></td>
      <td>
        <code>String, optional</code>
        <p>The version control system to use for fetching the repository. Useful
        for disabling importpath redirection if necessary. May be
        <code>"git"</code>, <code>"hg"</code>, <code>"svn"</code>,
        or <code>"bzr"</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>remote</code></td>
      <td>
        <code>String, optional</code>
        <p>The URI of the target remote repository, if this cannot be determined
        from the value of <code>importpath</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>urls</code></td>
      <td>
        <code>List of Strings, optional</code>
        <p>URLs for one or more source code archives.<br>
        See
        <a href="https://bazel.build/versions/master/docs/be/workspace.html#http_archive"><code>http_archive</code></a>
        for more details.</p>
      </td>
    </tr>
    <tr>
      <td><code>strip_prefix</code></td>
      <td>
        <code>String, optional</code>
        <p>The internal path prefix to strip when the archive is extracted.<br>
        See
        <a href="https://bazel.build/versions/master/docs/be/workspace.html#http_archive"><code>http_archive</code></a>
        for more details.</p>
      </td>
    </tr>
    <tr>
      <td><code>type</code></td>
      <td>
        <code>String, optional</code>
        <p>The type of the archive, only needed if it cannot be inferred from
        the file extension.<br>
        See
        <a href="https://bazel.build/versions/master/docs/be/workspace.html#http_archive"><code>http_archive</code></a>
        for more details.</p>
      </td>
    </tr>
    <tr>
      <td><code>sha256</code></td>
      <td>
        <code>String, optional</code>
        <p>The expected SHA-256 hash of the file downloaded.<br>
        See
        <a href="https://bazel.build/versions/master/docs/be/workspace.html#http_archive"><code>http_archive</code></a>
        for more details.</p>
      </td>
    </tr>
    <tr>
      <td><code>build_file_name</code></td>
      <td>
        <code>String, optional</code>
        <p>The name to use for the generated build files. Defaults to
        BUILD.bazel.</p>
      </td>
    </tr>
    <tr>
      <td><code>build_file_generation</code></td>
      <td>
        <code>String, optional</code>
        <p>Used to force build file generation.<br>
        <code>"off"</code> means do not generate build files.<br>
        <code>"on"</code> means always run gazelle, even if build files are
        already present<br>
        <code>"auto"</code> is the default and runs gazelle only if there is
        no root build file</p>
      </td>
    </tr>
    <tr>
      <td><code>build_tags</code></td>
      <td>
        <code>String, optional</code>
        <p>The set of tags to pass to gazelle when generating build files.</p>
      </td>
    </tr>
  </tbody>
</table>

#### Example:

The rule below fetches a repository with Git. Import path redirection is used
to automatically determine the true location of the repository.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "go_repository")

go_repository(
    name = "org_golang_x_tools",
    importpath = "golang.org/x/tools",
    commit = "663269851cdddc898f963782f74ea574bcd5c814",
)
```

The rule below fetches a repository archive with HTTP. GitHub provides HTTP
archives for all repositories. It's generally faster to fetch these than to
checkout a repository with Git, but the `strip_prefix` part can break if the
repository is renamed.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "go_repository")

go_repository(
    name = "org_golang_x_tools",
    importpath = "golang.org/x/tools",
    urls = ["https://codeload.github.com/golang/tools/zip/663269851cdddc898f963782f74ea574bcd5c814"],
    strip_prefix = "tools-663269851cdddc898f963782f74ea574bcd5c814",
    type = "zip",
)
```

### `new_go_repository`

**DEPRECATED** Use [`go_repository`](#go_repository) instead, which has the same
functionality.

## Build rules

### `go_prefix`

```bzl
go_prefix(prefix)
```

**DEPRECATED** Set the `importpath` attribute on all rules instead of using
`go_prefix`. See #721.

`go_prefix` declares the common prefix of the import path which is shared by
all Go libraries in the repository. A `go_prefix` rule must be declared in the
top-level BUILD file for any repository containing Go rules. This is used by the
Bazel rules during compilation to map import paths to dependencies. See the
[FAQ](#whats-up-with-the-go_default_library-name) for more information.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>prefix</code></td>
      <td>
        <code>String, required</code>
        <p>Global prefix used to fully qualify all Go targets.</p>
      </td>
    </tr>
  </tbody>
</table>

### `go_library`

```bzl
go_library(name, srcs, deps, data, importpath, gc_goopts, cgo, cdeps, copts, clinkopts)
```

`go_library` builds a Go library from a set of source files that are all part of
the same package.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go <code>.go</code> (at least one) or ASM <code>.s/.S</code>
        source files used to build the library. If <code>cgo = True</code>, then
        this list may also contain C sources and headers.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of Go libraries this library imports directly.</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of files needed by this rule at runtime.</p>
      </td>
    </tr>
    <tr>
      <td><code>importpath</code></td>
      <td>
        <code>String, optional</code>
        <p>The import path of this library. If unspecified, the library will
        have an implicit dependency on <code>//:go_prefix</code>, and the
        import path will be derived from the prefix and the library's label.</p>
      </td>
    </tr>
    <tr>
      <td><code>gc_goopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go compilation command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>cgo</code></td>
      <td>
        <code>Boolean, optional, defaults to false</code>
        <p>Whether this library contains cgo code. If true, <code>srcs</code>
        may contain cgo and C source files, <code>cdeps</code> may contain
        C/C++ libraries, and <code>copts</code> and <code>clinkopts</code>
        will be passed to the C compiler and linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>cdeps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of libraries that the cgo-generated library depends on. Only
        valid if <code>cgo = True</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>copts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C compiler when building cgo code.
        Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>clinkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C linker when linking a binary with
        cgo code. Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
  </tbody>
</table>

#### Example

```bzl
go_library(
    name = "go_default_library",
    srcs = [
        "foo.go",
        "bar.go",
    ],
    deps = [
        "//tools:go_default_library",
        "@org_golang_x_utils//stuff:go_default_library",
    ],
    importpath = "github.com/example/project/foo",
    visibility = ["//visibility:public"],
)
```

### `cgo_library`

```bzl
cgo_library(name, srcs, copts, clinkopts, cdeps, deps, data, gc_goopts)
```

**DEPRECATED** Use `go_library` with `cgo = True` instead.

`cgo_library` builds a Go library from a set of cgo source files that are part
of the same package. This library cannot contain pure Go code (see the note
below).

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go, C and C++ files that are processed to build a Go
        library.</p>
        <p>Those Go files must contain <code>import "C"</code>. C and C++ files
        can be anything allowed in <code>srcs</code> attribute of
        <code>cc_library</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>copts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>Add these flags to the C++ compiler</p>
      </td>
    </tr>
    <tr>
      <td><code>clinkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>Add these flags to the C++ linker</p>
      </td>
    </tr>
    <tr>
      <td><code>cdeps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of C/C++ libraries to be linked into the binary target.
        They must be <code>cc_library</code> rules.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of other Go libraries to be linked to this library</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of files needed by this rule at runtime.</p>
      </td>
    </tr>
    <tr>
      <td><code>gc_goopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go compilation command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
  </tbody>
</table>

#### NOTE

`srcs` cannot contain pure-Go files, which do not have `import "C"`.
So you need to define another `go_library` when you build a go package with
both cgo-enabled and pure-Go sources.

```bzl
cgo_library(
    name = "cgo_enabled",
    srcs = ["cgo-enabled.go", "foo.cc", "bar.S", "baz.a"],
)

go_library(
    name = "go_default_library",
    srcs = ["pure-go.go"],
    library = ":cgo_enabled",
)
```

### `go_binary`

```bzl
go_binary(name, srcs, deps, data, importpath, library, cgo, cdeps, copts, clinkopts, linkstamp, x_defs, gc_goopts, gc_linkopts)
```

`go_binary` builds an executable from a set of source files, which must all be
in the `main` package. You can run the binary with `bazel run`, or you can
build it with `bazel build` and run it directly.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go <code>.go</code> (at least one) or ASM <code>.s/.S</code>
        source files used to build the binary. If <code>cgo = True</code>, then
        this list may also contain C sources and headers.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of Go libraries this library imports directly.</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of files needed by this rule at runtime.</p>
      </td>
    </tr>
    <tr>
      <td><code>importpath</code></td>
      <td>
        <code>String, optional</code>
        <p>The import path of this binary. If unspecified, the binary will
        have an implicit dependency on <code>//:go_prefix</code>, and the
        import path will be derived from the prefix and the binary's label.
        Binary import paths are used to prepare repositories for export.</p>
      </td>
    </tr>
    <tr>
      <td><code>library</code></td>
      <td>
        <code>Label, optional</code>
        <p>A label of a <code>go_library</code> with the same packge name.
        When this binary is compiled, the <code>srcs</code>, <code>deps</code>,
        and <code>data</code> from this library will be included.</p>
      </td>
    </tr>
    <tr>
      <td><code>cgo</code></td>
      <td>
        <code>Boolean, optional, defaults to false</code>
        <p>Whether this binary contains cgo code. If true, <code>srcs</code>
        may contain cgo and C source files, <code>cdeps</code> may contain
        C/C++ libraries, and <code>copts</code> and <code>clinkopts</code>
        will be passed to the C compiler and linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>cdeps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of libraries that the cgo-generated library depends on. Only
        valid if <code>cgo = True</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>copts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C compiler when building cgo code.
        Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>clinkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C linker when linking a binary with
        cgo code. Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkstamp</code></td>
      <td>
        <code>String; optional; default is ""</code>
        <p>The name of a package containing global variables set by the linker
        as part of a link stamp. This may be used to embed version information
        in the generated binary. The -X flags will be of the form
        <code>-X <i>linkstamp</i>.KEY=VALUE</code>. The keys and values are
        read from <code>bazel-bin/volatile-status.txt</code> and
        <code>bazel-bin/stable-status.txt</code>. If you build with
        <code>--workspace_status_command=<i>./status.sh</i></code>, the output
        of <code>status.sh</code> will be written to these files.
        <a href="https://github.com/bazelbuild/bazel/blob/master/tools/buildstamp/get_workspace_status">
        Bazel <code>tools/buildstamp/get_workspace_status</code></a> is
        a good template which prints Git workspace status.</p>
      </td>
    </tr>
    <tr>
      <td><code>x_defs</code></td>
      <td>
        <code>Dict of strings; optional</code>
        <p>Additional -X flags to pass to the linker. Keys and values in this
        dict are passed as <code>-X key=value</code>. This can be used to set
        static information that doesn't change in each build.</p>
        <p>If the value is surrounded by curly brackets (e.g.
        <code>{VAR}</code>), then the value of the corresponding workspace
        status variable will be used instead. Valid workspace status variables
        include <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>, and
        custom variables provided through a
        <code>--workspace_status_command</code> as described in
        <code>linkstamp</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>gc_goopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go compilation command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>gc_linkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go link command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
  </tbody>
</table>

### `go_test`

```bzl
go_test(name, srcs, deps, data, importpath, library,
    cgo, cdeps, copts, clinkopts,
    linkstamp, x_defs, gc_goopts, gc_linkopts, rundir)
```

`go_test` builds a set of tests that can be run with `bazel test`. This can
contain sources for internal tests or external tests, but not both (see example
below).

To run all tests in the workspace, and print output on failure (the
equivalent of "go test ./..." from `go_prefix` in a `GOPATH` tree), run

```
bazel test --test_output=errors //...
```

You can run specific tests by passing the
[`--test_filter=pattern`](https://bazel.build/versions/master/docs/bazel-user-manual.html#flag--test_filter)
argument to Bazel. You can pass arguments to tests by passing
[`--test_arg=arg`](https://bazel.build/versions/master/docs/bazel-user-manual.html#flag--test_arg)
arguments to Bazel.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go <code>.go</code> (at least one) or ASM <code>.s/.S</code>
        source files used to build the test</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of other Go libraries to linked to this test target</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of files needed by this rule at runtime.</p>
      </td>
    </tr>
    <tr>
      <td><code>importpath</code></td>
      <td>
        <code>String, optional</code>
        <p>The import path of this test. If unspecified, the test will
        have an implicit dependency on <code>//:go_prefix</code>, and the
        import path will be derived from the prefix and the test's label.
        Test import paths are used to prepare repositories for export.</p>
      </td>
    </tr>
    <tr>
      <td><code>library</code></td>
      <td>
        <code>Label, optional</code>
        <p>A label of a <code>go_library</code> with the same packge name.
        When this test is compiled, the <code>srcs</code>, <code>deps</code>,
        and <code>data</code> from this library will be included. This is
        useful for creating internal tests which are compiled together with
        the package being tested.</p>
      </td>
    </tr>
    <tr>
      <td><code>cgo</code></td>
      <td>
        <code>Boolean, optional, defaults to false</code>
        <p>Whether this test contains cgo code. If true, <code>srcs</code>
        may contain cgo and C source files, <code>cdeps</code> may contain
        C/C++ libraries, and <code>copts</code> and <code>clinkopts</code>
        will be passed to the C compiler and linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>cdeps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of libraries that the cgo-generated library depends on. Only
        valid if <code>cgo = True</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>copts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C compiler when building cgo code.
        Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>clinkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to pass to the C linker when linking a test with
        cgo code. Only valid if <code>cgo = True</code>. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkstamp</code></td>
      <td>
        <code>String; optional; default is ""</code>
        <p>The name of a package containing global variables set by the linker
        as part of a link stamp. This may be used to embed version information
        in the generated test. The -X flags will be of the form
        <code>-X <i>linkstamp</i>.KEY=VALUE</code>. The keys and values are
        read from <code>bazel-bin/volatile-status.txt</code> and
        <code>bazel-bin/stable-status.txt</code>. If you build with
        <code>--workspace_status_command=<i>./status.sh</i></code>, the output
        of <code>status.sh</code> will be written to these files.
        <a href="https://github.com/bazelbuild/bazel/blob/master/tools/buildstamp/get_workspace_status">
        Bazel <code>tools/buildstamp/get_workspace_status</code></a> is
        a good template which prints Git workspace status.</p>
      </td>
    </tr>
    <tr>
      <td><code>x_defs</code></td>
      <td>
        <code>Dict of strings; optional</code>
        <p>Additional -X flags to pass to the linker. Keys and values in this
        dict are passed as <code>-X key=value</code>. This can be used to set
        static information that doesn't change in each build.</p>
        <p>If the value is surrounded by curly brackets (e.g.
        <code>{VAR}</code>), then the value of the corresponding workspace
        status variable will be used instead. Valid workspace status variables
        include <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>, and
        custom variables provided through a
        <code>--workspace_status_command</code> as described in
        <code>linkstamp</code>.</p>
      </td>
    </tr>    
    <tr>
      <td><code>gc_goopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go compilation command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>gc_linkopts</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>List of flags to add to the Go link command. Subject to
        <a href="https://bazel.build/versions/master/docs/be/make-variables.html#make-var-substitution">Make
        variable substitution</a> and
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#sh-tokenization">Bourne
        shell tokenization</a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>rundir</code></td>
      <td>
        <code>String, optional</code>
        <p>Path to the directory the test should run in. This should be relative
        to the root of the repository the test is defined in. By default, the
        test will run in the directory of the BUILD file that defines it.
        Use "." to run the test at the repository root.</p>
      </td>
    </tr>
  </tbody>
</table>

#### Example

To write an internal test, reference the library being tested with the `library`
attribute instead of the `deps` attribute. This will compile the test sources
into the same package as the library sources.

``` bzl
go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)

go_test(
    name = "go_default_test",
    srcs = ["lib_test.go"],
    library = ":go_default_library",
)
```

To write an external test, reference the library being tested with the `deps`
attribute.

``` bzl
go_library(
    name = "go_default_library",
    srcs = ["lib.go"],
)

go_test(
    name = "go_default_xtest",
    srcs = ["lib_x_test.go"],
    deps = [":go_default_library"],
)
```

### `go_proto_library`

```bzl
go_proto_library(name, srcs, deps, has_services)
```
<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for the underlying go_library rule. (usually `go_default_library`)</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Protocol Buffer <code>.proto</code>
        source files used to generate <code>.go</code> sources for a go_library</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of other go_proto_library(s) to depend on.
        Note: this also works if the label is a go_library,
        and there is a filegroup {name}+"_protos" (which is used for golang protobuf)</p>
      </td>
    </tr>
    <tr>
      <td><code>has_services</code></td>
      <td>
        <code>integer, optional, defaults to 0</code>
        <p>If 1, will generate with <code>plugins=grpc</code>
        and add the required dependencies.</p>
      </td>
    </tr>
    <tr>
      <td><code>ignore_go_package_option</code></td>
      <td>
        <code>integer, optional, defaults to 0</code>
        <p>If 1, will ignore the go_package option in the srcs proto files.
        Note: this will not work if the go_package options are specified in more
        than one line.
        </p>
      </td>
    </tr>
  </tbody>
</table>

### `go_embed_data`

```bzl
go_embed_data(name, src, srcs, out, package, var, flatten, string)
```
<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for the go_embed_data rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>src</code></td>
      <td>
        <code>Label, optional</code>
        <p>A single file to embed. This cannot be used at the same time as
        <code>srcs</code>. The generated file will have a variable of type
        <code>[]byte</code> or <code>string</code> with the contents of
        this file.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>A list of files to embed. This cannot be used at the same time as
        <code>src</code>. The generated file will have a variable of type
        <code>map[string][]byte</code> or <code>map[string]string</code> with
        the contents of each file. The map keys are relative paths the files
        from the repository root. Keys for files in external repositories will
        be prefixed with "external/repo/" where "repo" is the name of the
        external repository.</p>
      </td>
    </tr>
    <tr>
      <td><code>out</code></td>
      <td>
        <code>String, required</code>
        <p>Name of the .go file to generated. This may be referenced by
        other rules, such as <code>go_library</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>package</code></td>
      <td>
        <code>String, optional, defaults to directory base name</code>
        <p>Go package name for the generated .go file. This defaults to the
        name of the directory containing the <code>go_embed_data</code> rule.
        This attribute is required in the repository root directory though.</p>
      </td>
    </tr>
    <tr>
      <td><code>var</code></td>
      <td>
        <code>String, optional, defaults to "Data"</code>
        <p>Name of the variable that will contain the embedded data.</p>
      </td>
    </tr>
    <tr>
      <td><code>flatten</code></td>
      <td>
        <code>Boolean, optional, defaults to false</code>
        <p>If true and <code>srcs</code> is used, map keys are file base names
        instead of relative paths.</p>
      </td>
    </tr>
    <tr>
      <td><code>string</code></td>
      <td>
        <code>Boolean, optional, defaults to false</code>
        <p>If true, the embedded data will be stored as <code>string</code>
        instead of <code>[]byte</code>.</p>
      </td>
    </tr>
  </tbody>
</table>

#### Example:

The `foo_data` rule below will generate a file named `foo_data.go`, which can
be included in a library. Gazelle will find and add these files
automatically.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "go_embed_data", "go_library")

go_embed_data(
    name = "foo_data",
    src = "foo.txt",
    out = "foo_data.go",
    package = "foo",
    string = True,
    var = "Data",
)

go_library(
    name = "go_default_library",
    srcs = ["foo_data.go"],
)
```

The generated file will look like this:

```go
// Generated by go_embed_data for //:foo_data. DO NOT EDIT.

package foo



var Data = "Contents of foo.txt"
```
