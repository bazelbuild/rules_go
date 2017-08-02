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
* `# gazelle:exclude file-or-directory-name` at the top level of a BUILD file
  will instruct gazelle to exclude the named file or directory from its
  analysis. Gazelle won't recurse into excluded directories. This directive
  may be used multiple times to exclude multiple files (one per line). Spaces
  within the file name are significant, but leading and trailing spaces are
  stripped.


## Known Shortcomings

* bazel-style auto generating BUILD (where the library name is other than go_default_library)
