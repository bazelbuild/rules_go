// Command fetch_repo is similar to "go get -d" but it works even if the given
// repository path is not a buildable Go package and it checks out a specific
// revision rather than the latest revision.
//
// The difference between fetch_repo and "git clone" or {new_,}git_repository is
// that fetch_repo recognizes import redirection of Go and it supports other
// version control systems than git.
//
// These differences help us to manage external Go repositories in the manner of
// Bazel.
package main

import (
	"flag"
	"fmt"
	"log"

	"golang.org/x/tools/go/vcs"
)

var (
	remote = flag.String("remote", "", "Go importpath to the repository fetch")
	rev    = flag.String("rev", "", "target revision")
	dest   = flag.String("dest", "", "destination directory")
)

func run() error {
	r, err := vcs.RepoRootForImportPath(*remote, true)
	if err != nil {
		return err
	}
	if *remote != r.Root {
		return fmt.Errorf("not a root of a repository: %s", *remote)
	}
	return r.VCS.CreateAtRev(*dest, r.Repo, *rev)
}

func main() {
	flag.Parse()

	if err := run(); err != nil {
		log.Fatal(err)
	}
}
