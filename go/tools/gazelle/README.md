# Gazelle build file generator

Gazelle is a build file generator for Go projects. It can create new
BUILD.bazel files for a project that follows "go build" conventions, and it
can update existing build files to include new files and options. Gazelle can
be invoked directly in a project workspace, or it can be run on an external
repository during the build as part of the `go_repository` rule.

*Gazelle is under active development. Its interface and the rules it generates
may change.*

## Contents

* [Setup](#setup)
  * [Running Gazelle with Bazel](#running-gazelle-with-bazel)
  * [Running Gazelle separately](#running-gazelle-separately)
* [Usage](#usage)
  * [Command line](#command-line)
  * [Bazel rule](#bazel-rule)
  * [Directives](#directives)

## Setup

### Running Gazelle with Bazel

To use Gazelle in a new project, add the following to the BUILD or BUILD.bazel
file in the root directory of your repository:

```bzl
load("@io_bazel_rules_go//go:def.bzl", "gazelle")

gazelle(
    name = "gazelle",
    prefix = "github.com/example/project",
)
```

Replace the string in `prefix` with the portion of your import path that
corresponds to your repository.

After adding those rules, run the command below:

```
bazel run //:gazelle
```

This will generate new BUILD.bazel files for your project. You can run the same
command in the future to update existing BUILD.bazel files to include new source
files or options.

### Running Gazelle separately

If you have a Go SDK installed, you can install Gazelle in your `GOPATH` with
the command below:

```
go get -u github.com/bazelbuild/rules_go/go/tools/gazelle/gazelle
```

Make sure to re-run this command to upgrade Gazelle whenever you upgrade
rules_go in your repository.

To generate BUILD.bazel files in a new project, run the command below, replacing
the prefix with the portion of your import path that corresponds to your
repository.

```
gazelle -go_prefix github.com/my/project
```

The prefix only needs to be specified the first time you run Gazelle. To update
existing BUILD.bazel files, you can just run `gazelle` without arguments.

## Usage

### Command line

```
gazelle <command> [flags...] [package-dirs...]
```

The first argument to Gazelle may be one of the commands below. If no command
is specified, `update` is assumed.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Commands</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>update</code></td>
      <td>Gazelle will create new build files and update existing build files.
      New rules may be created. Files, dependencies, and options may be added or
      removed from existing rules.</td>
    </tr>
    <tr>
      <td><code>fix</code></td>
      <td>In addition to the changes made in <code>update</code>, Gazelle will
      remove deprecated usage of the Go rules, analogous to <code>go fix</code>.
      For example, <code>cgo_library</code> will be consolidated with
      <code>go_library</code>. This may delete rules, so it's not turned on by
      default.</td>
    </tr>
  </tbody>
</table>

Gazelle accepts a list Go of package directories to process. If no directories
are given, it defaults to the current directory when run on the command line or
the repository root when run with Bazel. It recursively traverses
subdirectories.

Gazelle accepts the following flags:

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <tr>
    <th colspan="2">Flags</th>
  </tr>
  <tbody>
    <tr>
      <td><code>-build_file_name file1,file2...</code></td>
      <td>
        <p>Comma-separated list of file names. Defaults to
        <code>BUILD.bazel,BUILD</code></p>
        <p>Gazelle recognizes these files as Bazel build files. New files will
        use the first name in this list. Use this if your project contains
        non-Bazel files named <code>BUILD</code> (or <code>build</code> on
        case-insensitive file systems).</p>
      </td>
    </tr>
    <tr>
      <td><code>-build_tags tag1,tag2</code></td>
      <td>
        <p>List of Go build tags Gazelle will consider to be true.</p>
        <p>Gazelle applies build constraints when generating Go rules. It
        assumes certain tags are true on certain platforms (for example,
        <code>amd64,linux</code>). It assumes all Go release tags are true
        (for example, <code>go1.8</code>). It considers other tags to be false
        (for example, <code>ignore</code>). This flag overrides that
        behavior.</p>
      </td>
    </tr>
    <tr>
      <td><code>-external external|vendored</code></td>
      <td>
        <p>Determines how Gazelle resolves import paths. Defaults to
        <code>external</code>.</p>
        <p>Gazelle translates Go import paths to Bazel labels when resolving
        library dependencies. Import paths that start with the
        <code>go_prefix</code> are resolved to local labels, but other imports
        are resolved based on this mode. In <code>external</code> mode, paths
        are resolved using an external dependency in the <code>WORKSPACE</code>
        file (Gazelle does not create or maintain these dependencies yet). In
        <code>vendored</code> mode, paths are resolved to a library in the
        <code>vendor</code> directory.</p>
      </td>
    </tr>
    <tr>
      <td><code>-go_prefix github.com/my/project</code></td>
      <td>
        <p>A prefix of import paths for libraries in the repository that
        corresponds to the repository root. Gazelle infers this from the
        <code>go_prefix</code> rule in the root <code>BUILD.bazel</code> file,
        if it exists. If not, this option is mandatory.</p>
        <p>This prefix is used to determine whether an import path refers to
        a library in the current repository or an external dependency.</p>
      </td>
    </tr>
    <tr>
      <td><code>-repo_root dir</code></td>
      <td>
        <p>The root directory of the repository. Gazelle normally infers this
        to be the directory containing the <code>WORKSPACE</code> file.</p>
        <p>Gazelle will not process packages outside this directory.</p>
      </td>
    </td>
    <tr>
      <td><code>-known_import example.com</code></td>
      <td>
        <p>Skips import path resolution for a known domain. May be repeated.</p>
        <p>When Gazelle resolves an import path to an external dependency, it
        attempts to discover the remote repository root over HTTP. Gazelle skips
        this discovery step for a few well-known domains with predictable
        structure, like golang.org and github.com. This flag specifies
        additional domains to skip, which is useful in situations where the
        lookup would fail for some reason.</p>
      </td>
    </tr>
    <tr>
      <td><code>-mode fix|print|diff</code></td>
      <td>
        <p>Method for emitting merged build files. Defaults to
        <code>fix</code>.</p>
        <p>In <code>fix</code> mode, Gazelle writes generated and merged files
        to disk. In <code>print</code> mode, it prints them to stdout. In
        <code>diff</code> mode, it prints a unified diff.</p>
      </td>
    </tr>
  </tbody>
</table>

### Bazel rule

When Gazelle is run by Bazel, most of the flags above can be encoded in the
`gazelle` macro. For example:

```bzl
load("@io_bazel_rules_go//go:def.bzl", "gazelle")

gazelle(
    name = "gazelle",
    command = "fix",
    prefix = "github.com/example/project",
    external = "vendored",
    build_tags = [
        "integration",
        "debug",
    ],
    args = [
        "-build_file_name",
        "BUILD,BUILD.bazel",
    ],
)
```

### Directives

Gazelle supports several directives, written as comments in build files.

* `# gazelle:ignore`: may be written at the top level of any build file. Gazelle
  will not update files with this comment.
* `# gazelle:exclude file-or-directory`: may be written at the top level of any
  build file. Gazelle will ignore the named file in the build file's
  directory. If it is a source file, Gazelle won't include it in any rules. If
  it is a directory, Gazelle will not recurse into it. This directive may be
  repeated to exclude multiple files, one per line.
* `# keep`: may be written before a rule to prevent the rule from being updated
  or after a source file, dependency, or flag to prevent it from being removed.

#### Example:

Suppose you have a library that includes a generated .go file. Gazelle won't
know what imports to resolve, so you may need to add dependencies manually with
`# keep` comments.

```bzl
load("@io_bazel_rules_go//go:def.bzl", "go_library")
load("@com_github_example_gen//:gen.bzl", "gen_go_file")

gen_go_file(
    name = "magic",
    srcs = ["magic.go.in"],
    outs = ["magic.go"],
)

go_library(
    name = "go_default_library",
    srcs = ["magic.go"],
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_example_gen//:go_default_library",  # keep
    ],
)
```
