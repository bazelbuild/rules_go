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
	remote     = flag.String("remote", "", "The URI of the remote repository. Must be used with the --vcs flag.")
	cmd        = flag.String("vcs", "", "Version control system to use to fetch the repository. Should be one of: git,hg,svn,bzr. Must be used with the --remote flag.")
	rev        = flag.String("rev", "", "target revision")
	dest       = flag.String("dest", "", "destination directory")
	importpath = flag.String("importpath", "", "Go importpath to the repository fetch")

	// Used for overriding in tests to disable network calls.
	repoRootForImportPath = vcs.RepoRootForImportPath
)

func getRepoRoot(remote, cmd, importpath string) (*vcs.RepoRoot, error) {
	if (cmd == "") != (remote == "") {
		return nil, fmt.Errorf("--remote should be used with the --vcs flag. If this is an import path, use --importpath instead.")
	}

	if cmd != "" && remote != "" {
		v := vcs.ByCmd(cmd)
		if v == nil {
			return nil, fmt.Errorf("invalid VCS type: %s", cmd)
		}
		return &vcs.RepoRoot{
			VCS:  v,
			Repo: remote,
			Root: importpath,
		}, nil
	}

	// User did not give us complete information for VCS / Remote.
	// Try to figure out the information from the import path.
	r, err := repoRootForImportPath(importpath, true)
	if err != nil {
		return nil, err
	}
	if importpath != r.Root {
		return nil, fmt.Errorf("not a root of a repository: %s", importpath)
	}
	return r, nil
}

func run() error {
	r, err := getRepoRoot(*remote, *cmd, *importpath)
	if err != nil {
		return err
	}
	return r.VCS.CreateAtRev(*dest, r.Repo, *rev)
}

func main() {
	flag.Parse()

	if err := run(); err != nil {
		log.Fatal(err)
	}
}
