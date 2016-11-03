# Go rules

Bazel ≥0.3.1 | linux-x86_64 | ubuntu_15.10-x86_64 | darwin-x86_64
:---: | :---: | :---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_go.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_go) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_15.10-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_15.10-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)](http://ci.bazel.io/job/rules_go/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="#go_repositories">go_repositories</a></li>
    <li><a href="#go_repository">go_repository</a></li>
    <li><a href="#new_go_repository">new_go_repository</a></li>
    <li><a href="#go_prefix">go_prefix</a></li>
    <li><a href="#go_library">go_library</a></li>
    <li><a href="#cgo_library">cgo_library</a></li>
    <li><a href="#go_binary">go_binary</a></li>
    <li><a href="#go_test">go_test</a></li>
    <li><a href="#go_proto_library">go_proto_library</a></li>
  </ul>
</div>

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

* build constraints/tags (`//+build` comments - see <a
  href="https://golang.org/pkg/go/build/">here</a>))
* bazel-style auto generating BUILD (where the library name is other than go_default_library)
* C/C++ interoperation except cgo (swig etc.)
* race detector
* coverage
* test sharding

Note: this repo requires bazel >= 0.4.4 to function (due to the use of BUILD.bazel files in bazelbuild/buildifier)

## Setup

* Decide on the name of your package, eg. `github.com/joe/project`
* Add the following to your WORKSPACE file:

    ```bzl
    git_repository(
        name = "io_bazel_rules_go",
        remote = "https://github.com/bazelbuild/rules_go.git",
        tag = "0.4.0",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_repositories")

    go_repositories()
    ```

* Add a `BUILD` file to the top of your workspace, declaring the name of your
  workspace using `go_prefix`. This prefix is used for Go's "import" statements
  to refer to packages within your own project, so it's important to choose a
  prefix that might match the location that another user might choose to put
  your code into.

    ```bzl
    load("@io_bazel_rules_go//go:def.bzl", "go_prefix")

    go_prefix("github.com/joe/project")
    ```

* For a library `github.com/joe/project/lib`, create `lib/BUILD`, containing
  a single library with the special name "go_default_library." Using this name tells
  Bazel to set up the files so it can be imported in .go files as (in this
  example) `github.com/joe/project/lib`.

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

* For instructions on how to depend on external libraries, see Vendoring.md.

## FAQ

### Can I still use the `go` tool?

Yes, this setup was deliberately chosen to be compatible with the `go`
tool. Make sure your workspace appears under

```sh
$GOROOT/src/github.com/joe/project/
```

eg.

```sh
mkdir -p $GOROOT/src/github.com/joe/
ln -s my/bazel/workspace $GOROOT/src/github.com/joe/project
```

and it should work.

## Disclaimer

These rules are not supported by Google's Go team.

<a name="go_repositories"></a>
## go\_repositories

```bzl
go_repositories()
```

Instantiates external dependencies to Go toolchain in a WORKSPACE.
All the other workspace rules and build rules assume that this rule is
placed in the WORKSPACE.


<a name="go_repository"></a>
## go\_repository

```bzl
go_repository(name, importpath, remote, commit, tag)
```

Fetches a remote repository of a Go project, expecting it contains `BUILD`
files. It is an analogy to `git_repository` but it recognizes importpath
redirection of Go.

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
        <p>An import path in Go, which also provides a default value for the
	root of the target remote repository</p>
      </td>
    </tr>
    <tr>
      <td><code>remote</code></td>
      <td>
        <code>String, optional</code>
        <p>The root of the target remote repository, if this differs from the
	value of <code>importpath</code></p>
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


<a name="new_go_repository"></a>
## new\_go\_repository

```bzl
new_go_repository(name, importpath, remote, commit, tag)
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
        <code>String, required</code>
        <p>An import path in Go, which also provides a default value for the
	root of the target remote repository</p>
      </td>
    </tr>
    <tr>
      <td><code>remote</code></td>
      <td>
        <code>String, optional</code>
        <p>The root of the target remote repository, if this differs from the
	value of <code>importpath</code></p>
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


<a name="go_prefix"></a>
## go\_prefix

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

<a name="go_library"></a>
## go\_library

```bzl
go_library(name, srcs, deps, data)
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
  </tbody>
</table>

<a name="cgo_library"></a>
## cgo\_library

```bzl
cgo_library(name, srcs, copts, clinkopts, cdeps, deps, data)
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
  </tbody>
</table>

### NOTE

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

<a name="go_binary"></a>
## go\_binary

```bzl
go_binary(name, srcs, deps, data, linkstamp)
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
  </tbody>
</table>

<a name="go_test"></a>
## go\_test

```bzl
go_test(name, srcs, deps, data)
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
  </tbody>
</table>



....
<a name="go_proto_library"></a>
## go\_proto\_library

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
  </tbody>
</table>
