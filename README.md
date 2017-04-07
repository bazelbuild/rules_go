# Go rules for [Bazel](https://bazel.build/)

Bazel ≥0.4.4 | linux-x86_64 | ubuntu_15.10-x86_64 | darwin-x86_64
:---: | :---: | :---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_go.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_go) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_15.10-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_15.10-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)

## Announcements

* **April 7, 2017** Builds using rules_go recently broke
([#361](https://github.com/bazelbuild/rules_go/issues/361)) because of a name
change in buildifier, one of our dependencies. You can upgrade to `0.3.4`,
`0.4.2`, or `master` to get your build working again.

## Contents

* [Overview](#overview)
* [Setup](#setup)
* [Generating build files](#generating-build-files)
* [FAQ](#faq)
* [Repository rules](#repository-rules)
 * [go_repositories](#go_repositories)
 * [go_repository](#go_repository)
 * [new_go_repository](#new_go_repository)
* [Build rules](#build-rules)
 * [go_prefix](#go_prefix)
 * [go_library](#go_library)
 * [cgo_library](#cgo_library)
 * [go_binary](#go_binary)
 * [go_test](#go_test)
 * [go_proto_library](#go_proto_library)

## Overview

The rules should be considered experimental. They support:

* libraries
* binaries
* tests
* vendoring
* cgo
* auto generating BUILD files via gazelle
* protocol buffers (via extension //proto:go_proto_library.bzl)

They currently do not support (in order of importance):

* bazel-style auto generating BUILD (where the library name is other than
  go_default_library)
* C/C++ interoperation except cgo (swig etc.)
* race detector
* coverage
* test sharding

Note: this repo requires bazel ≥ 0.4.4 to function (due to the use of
BUILD.bazel files in bazelbuild/buildifier).

## Setup

* Decide on the name of your package, eg. `github.com/joe/project`. It's
  important to choose a name that will match where others will download your
  code. This will be a prefix for import paths within your project.
* Add the following to your WORKSPACE file:

    ```bzl
    git_repository(
        name = "io_bazel_rules_go",
        remote = "https://github.com/bazelbuild/rules_go.git",
        tag = "0.4.2",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_repositories")

    go_repositories()
    ```

* If your project follows the structure that `go build` uses, you
  can [generate your `BUILD` files](#generating-build-files) with Gazelle. If
  not, read on.
* Add a `BUILD` file to the top of your project. Declare the name of your
  workspace using `go_prefix`. This is used by Bazel to translate between build
  targets and import paths.

    ```bzl
    load("@io_bazel_rules_go//go:def.bzl", "go_prefix")

    go_prefix("github.com/joe/project")
    ```

* For a library `github.com/joe/project/lib`, create `lib/BUILD`, containing
  a single library with the special name "`go_default_library`." Using this name
  tells Bazel to set up the files so it can be imported in .go files as (in this
  example) `github.com/joe/project/lib`. See the
  [FAQ](#whats-up-with-the-go_default_library-name) below for more information
  on this name.

    ```bzl
    load("@io_bazel_rules_go//go:def.bzl", "go_library")

    go_library(
        name = "go_default_library",
        srcs = ["file.go"]
    )
    ```

* Inside your project, you can use this library by declaring a dependency on
  the full Bazel name (including `:go_default_library`), and in the .go files,
  import it as shown above.

    ```bzl
    go_binary(
        ...
        deps = ["//lib:go_default_library"]
    )
    ```

* To declare a test,

    ```bzl
    go_test(
        name = "mytest",
        srcs = ["file_test.go"],
        library = ":go_default_library"
    )
    ```

* For instructions on how to depend on external libraries,
  see [Vendoring.md](Vendoring.md).

## Generating build files

If you project is compatible with the `go` tool, you can generate and update
your `BUILD` files automatically using [Gazelle](go/tools/gazelle/README.md),
a command line tool which is part of this repository.

* You can install Gazelle using the command below. This assumes this repository
  is checked out under [GOPATH](https://github.com/golang/go/wiki/GOPATH).

```
go install github.com/bazelbuild/rules_go/go/tools/gazelle/gazelle
```

* To run Gazelle for the first time, run the command below from your project
  root directory.

```
gazelle -go_prefix github.com/joe/project
```

* To update your `BUILD` files later, just run `gazelle`.
* By default, Gazelle assumes external dependencies are present in
  your `WORKSPACE` file, following a certain naming convention. For example, it
  expects the repository for `github.com/jane/utils` to be named
  `@com_github_jane_utils`. If you prefer to use vendoring, run `gazelle` with
  `-external vendored`. See [Vendoring.md](Vendoring.md).

See the [Gazelle README](go/tools/gazelle/README.md) for more information.

## FAQ

### Can I still use the `go` tool?

Yes, this setup was deliberately chosen to be compatible with the `go`
tool. Make sure your workspace appears under

```sh
$GOPATH/src/github.com/joe/project/
```

eg.

```sh
mkdir -p $GOPATH/src/github.com/joe/
ln -s my/bazel/workspace $GOPATH/src/github.com/joe/project
```

and it should work.

### What's up with the `go_default_library` name?

This is used to keep import paths consistent in libraries that can be built
with `go build`.

In order to compile and link correctly, the Go rules need to be able to
translate between Bazel labels and Go import paths. Let's say your project name
is `github.com/joe/project`, and you have a library in the `foo/bar` directory
named `bar`. The Bazel label for this would be `//foo/bar:bar`. The Go import
path for this would be `github.com/joe/project/foo/bar/bar`.

This is not what `go build` expects; it expects
`github.com/joe/project/foo/bar/bar` to refer to a library built from .go files
in the directory `foo/bar/bar`.

In order to avoid this conflict, you can name your library `go_default_library`.
The full Bazel label for this library would be `//foo/bar:go_default_library`.
The import path would be `github.com/joe/project/foo/bar`.

`BUILD` files generated with Gazelle, including those in external projects
imported with [`go_repository`](#go_repository), will have libraries named
`go_default_library` automatically.

## Repository rules

### `go_repositories`

``` bzl
go_repositories(go_version, go_linux, go_darwin)
```

Adds Go-related external dependencies to the WORKSPACE, including the Go
toolchain and standard library. All the other workspace rules and build rules
assume that this rule is placed in the WORKSPACE.

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
      <td><code>go_version</code></td>
      <td>
        <code>String, optional</code>
        <p>The Go version to use. If none of the parameters are specified, the
        most recent stable version of Go will be used.</p>
      </td>
    </tr>
    <tr>
      <td><code>go_linux</code></td>
      <td>
        <code>String, optional</code>
        <p>A custom Go repository to use when building on Linux. See below for
        an example. This cannot be specified at the same time as
        <code>go_version</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>go_darwin</code></td>
      <td>
        <code>String, optional</code>
        <p>A custom Go repository to use when building on macOS. See below for
        an example. This cannot be specified at the same time as
        <code>go_version</code>.</p>
      </td>
    </tr>
  </tbody>
</table>

#### Example:

Suppose you have your own fork of Go, perhaps with some custom patches
applied. To use that toolchain with these rules, declare the toolchain
repository with a workspace rule, such as `new_git_repository` or
`local_repository`, then pass it to `go_repositories` as below. The rules expect
Go binaries and libraries to be present in the `bin/` and `pkg/` directories, so
you'll need a different repository for each supported host platform.

``` bzl
new_git_repository(
    name = "custom_go_linux",
    remote = "https://github.com/j_r_hacker/go_linux",
    tag = "2.5",
    build_file_content = "",
)

new_git_repository(
    name = "custom_go_darwin",
    remote = "https://github.com/j_r_hacker/go_darwin",
    tag = "2.5",
    build_file_content = "",
)

go_repositories(
    go_linux = "@custom_go_linux",
    go_darwin = "@custom_go_darwin",
)
```

### `go_repository`

```bzl
go_repository(name, importpath, remote, vcs, commit, tag)
```

Fetches a remote repository of a Go project, expecting it contains `BUILD`
files. It is an analogy to `git_repository` but it recognizes importpath
redirection of Go.

Either `importpath` or `remote` may be specified. To bypass importpath
redirection, specify both `remote` and `vcs`.

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
        <code>String, optional</code>
        <p>An import path in Go, which also provides a default value for the
        root of the target remote repository</p>
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
      <td><code>vcs</code></td>
      <td>
        <code>String, optional</code>
        <p>The version control system to use for fetching the repository. Useful
        for disabling importpath redirection if necessary.</p>
      </td>
    </tr>
    <tr>
      <td><code>commit</code></td>
      <td>
        <code>String, optional</code>
        <p>The commit hash to checkout in the repository.</p>
        <p>Note that one of either <code>commit</code> or <code>tag</code> must be defined.</p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <code>String, optional</code>
        <p>The tag to checkout in the repository.</p>
        <p>Note that one of either <code>commit</code> or <code>tag</code> must be defined.</p>
      </td>
    </tr>
  </tbody>
</table>

### `new_go_repository`

```bzl
new_go_repository(name, importpath, remote, vcs, commit, tag)
```

Fetches a remote repository of a Go project and automatically generates
`BUILD` files in it.  It is an analogy to `new_git_repository` but it recognizes
importpath redirection of Go.

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
        <code>String, optional</code>
        <p>An import path in Go, which also provides a default value for the
        root of the target remote repository</p>
      </td>
    </tr>
    <tr>
      <td><code>remote</code></td>
      <td>
        <code>String, optional</code>
        <p>The URI of the target remote repository, if this differs from the
        value of <code>importpath</code></p>
      </td>
    </tr>
    <tr>
      <td><code>vcs</code></td>
      <td>
        <code>String, optional</code>
        <p>The version control system to use for fetching the repository.</p>
      </td>
    </tr>
    <tr>
      <td><code>commit</code></td>
      <td>
        <code>String, optional</code>
        <p>The commit hash to checkout in the repository.</p>
        <p>Note that one of either <code>commit</code> or <code>tag</code> must be defined.</p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <code>String, optional</code>
        <p>The tag to checkout in the repository.</p>
        <p>Note that one of either <code>commit</code> or <code>tag</code> must be defined.</p>
      </td>
    </tr>
  </tbody>
</table>

## Build rules

### `go_prefix`

```bzl
go_prefix(prefix)
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
      <td><code>prefix</code></td>
      <td>
        <code>String, required</code>
        <p>Global prefix used to fully qualify all Go targets.</p>
        <p>
          In Go, imports are always fully qualified with a URL, eg.
          <code>github.com/user/project</code>. Hence, a label <code>//foo:bar
          </code> from within a Bazel workspace must be referred to as
          <code>github.com/user/project/foo/bar</code>. To make this work, each
          rule must know the repository's URL. This is achieved, by having all
          go rules depend on a globally unique target that has a
          <code>go_prefix</code> transitive info provider.
        </p>
      </td>
    </tr>
  </tbody>
</table>

### `go_library`

```bzl
go_library(name, srcs, deps, data, library, gc_goopts)
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
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go <code>.go</code> (at least one) or ASM <code>.s/.S</code>
        source files used to build the library</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of other libraries to linked to this library target</p>
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
      <td><code>library</code></td>
      <td>
        <code>Label, optional</code>
        <p>A label of another rule with Go `srcs`, `deps`, and `data`. When this
        library is compiled, the sources from this attribute will be combined
        with `srcs`. This is commonly used to depend on Go sources in
        `cgo_library`.</p>
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

### `cgo_library`

```bzl
cgo_library(name, srcs, copts, clinkopts, cdeps, deps, data, gc_goopts)
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
go_binary(name, srcs, deps, data, library, linkstamp, x_defs, gc_goopts, gc_linkopts)
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
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of labels, required</code>
        <p>List of Go <code>.go</code> (at least one) or ASM <code>.s/.S</code>
        source files used to build the binary</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>List of other Go libraries to linked to this binary target</p>
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
      <td><code>library</code></td>
      <td>
        <code>Label, optional</code>
        <p>A label of another rule with Go `srcs`, `deps`, and `data`. When this
        binary is compiled, the sources from this attribute will be combined
        with `srcs`. This is commonly used to depend on Go sources in
        `cgo_library`.</p>
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
        dict are passed as `-X key=value`. This can be used to set static
        information that doesn't change in each build.</p>
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
go_test(name, srcs, deps, data, library, gc_goopts, gc_linkopts)
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
      <td><code>library</code></td>
      <td>
        <code>Label, optional</code>
        <p>A label of another rule with Go `srcs`, `deps`, and `data`. When this
        library is compiled, the sources from this attribute will be combined
        with `srcs`.</p>
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

#### NOTE

In order for a `go_test` to refer to private definitions within a `go_library`,
it must on the library's sources through the `library` attribute, _not_ the
`deps` attribute.

``` bzl
go_library(
    name = "go_default_library",
    srcs = glob(["*.go"], exclude=["*_test.go"]),
)

go_test(
    name = "go_default_test",
    srcs = glob(["*_test.go"]),
    library = ":go_default_library",
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
        <p>A unique name for the underlying go_library rule.</p>
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
