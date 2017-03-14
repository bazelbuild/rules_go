# Gazelle BUILD file generator

## Setup

For local use, in `$GOPATH/src/github.com/bazelbuild/rules_go/go/tools/gazelle/gazelle`
run `go install`

## Usage

  gazelle
  
Which will fix all build files in the current directory plus subdirectories.

##  First time use for a project

  gazelle -go_prefix $PROJECT
  
If you don't even have a WORKSPACE file yet, you also need to set -repo_root

## Special Markers

* `# keep` on an entry to a `deps` or `srcs` attribute will instruct gazelle to keep that element
even if it thinks otherwise
* `# gazelle:ignore` at the top level of a BUILD file will instruct gazelle to leave the file alone.

## Known Shortcomings

* bazel-style auto generating BUILD (where the library name is other than go_default_library)
