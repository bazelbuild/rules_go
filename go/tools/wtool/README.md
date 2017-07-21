# Basic workspace tool `wtool`

## Setup

For local use, in `$GOPATH/src/github.com/bazelbuild/rules_go/go/tools/wtool`
run `go install`

## Usage examples

    wtool com_github_golang_glog [<bazel-importpath2> ...]

  OR

    wtool -asis github.com/golang/glog [<go-importpath2> ...]

Which will add the HEAD commit of this dependency as a `go_repository` to your
WORKSPACE file.

    go_repository(
      name = "com_github_golang_glog",
      commit = "23def4e6c14b4da8ac2ed8007337bc5eb5007998",
      importpath = "github.com/golang/glog",
    )

## Known Shortcomings

* The default mode assumes that every '_' is a '.', which is not always true.
In those cases use the actual importpath and '-asis'
* Does not load skylark files and is thus unaware if the given repository is already
transitively loaded.
* Adds the dependency at HEAD, does not allow specification of a specific commit or tag.
