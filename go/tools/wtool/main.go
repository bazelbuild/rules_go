/*
wtool augments your bazel WORKSPACE file with go_repository entries

Example Usage:
  wtool com_github_golang_glog com_google_cloud_go
will add 2 go_repository rules to your WORKSPACE
by converting com_github_golang_glog -> github.com/golang/glog
and so forth and then doing a 'git ls-remote' to get
the latest commit.

If wtool cannot figure out the bazel -> Go mapping, try
Other Usage:
  wtool -asis github.com/golang/glog
which takes an importpath, and computes the bazel name + ls-remote as above.
*/
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/resolve"
	"github.com/bazelbuild/bazel-gazelle/wspace"
	bf "github.com/bazelbuild/buildtools/build"
	"golang.org/x/tools/go/vcs"
)

var (
	asis    = flag.Bool("asis", false, "if true, leave the import names as-is (by default they are treated as bazel converted names like org_golang_x_net")
	verbose = flag.Bool("verbose", false, "if true, logging extra information")

	knownPaths = map[string]string{
		"org_golang_google": "google.golang.org/",
		"com_google_cloud":  "cloud.google.com/",
	}
)

func main() {
	flag.Parse()
	if err := run(flag.Args()); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}
	w, err := wspace.Find(cwd)
	if err != nil {
		return err
	}
	p := filepath.Join(w, "WORKSPACE")
	b, err := ioutil.ReadFile(p)
	if err != nil {
		return err
	}
	f, err := bf.Parse(p, b)
	if err != nil {
		return err
	}
	for _, arg := range args {
		imp, err := findImport(arg)
		if err != nil {
			return err
		}
		// TODO(pmbethe09): ignore or maybe update sha1 if already defined in workspace.
		f.Stmt = append(f.Stmt, imp)
	}
	updateLoad(f)
	bf.Rewrite(f, nil)
	return ioutil.WriteFile(f.Path, bf.Format(f), 0644)
}

func nameAndImportpath(name string) (string, string, error) {
	if *asis {
		return resolve.ImportPathToBazelRepoName(name), name, nil
	}
	s := strings.Split(name, "_")
	if len(s) < 4 {
		return "", "", fmt.Errorf("workspace names must be 4-parts or longer: %q", name)
	}
	rest := strings.Join(s[3:], "-")
	for k, v := range knownPaths {
		if strings.HasPrefix(name, k) {
			return name, v + rest, nil
		}
	}
	return name, strings.Join([]string{s[1] + "." + s[0], s[2], rest}, "/"), nil
}

func findImport(nameIn string) (bf.Expr, error) {
	name, importpath, err := nameAndImportpath(nameIn)
	if err != nil {
		return nil, err
	}
	if *verbose {
		log.Printf(importpath)
	}
	r, err := vcs.RepoRootForImportPath(importpath, false)
	if err != nil {
		return nil, err
	}
	if r.VCS.Cmd != "git" {
		return nil, fmt.Errorf("only git supported, not %q", r.VCS.Cmd)
	}
	// TODO(pmbethe09): allow ref to be provided, e.g. com_github_golang_glog:mybranch
	commit, err := lsRemote(r.Repo)
	if err != nil {
		return nil, err
	}
	return &bf.CallExpr{
		X: &bf.LiteralExpr{Token: "go_repository"},
		List: []bf.Expr{
			attr("name", name),
			attr("importpath", importpath),
			attr("commit", commit),
		},
	}, nil
}

func attr(key, val string) *bf.BinaryExpr {
	return &bf.BinaryExpr{
		X:  &bf.LiteralExpr{Token: key},
		Op: "=",
		Y:  &bf.StringExpr{Value: val},
	}
}

func lsRemote(repo string) (string, error) {
	cmd := exec.Command("git", "ls-remote", repo, "HEAD")
	r, err := cmd.StdoutPipe()
	if err != nil {
		return "", err
	}
	if err := cmd.Start(); err != nil {
		return "", err
	}
	b := bufio.NewScanner(r)
	if !b.Scan() {
		if err := b.Err(); err != nil {
			return "", err
		}
		return "", fmt.Errorf("nothing returned from ls-remote %q", repo)
	}
	if *verbose {
		log.Printf(b.Text())
	}
	go cmd.Wait()
	return strings.Split(b.Text(), "\t")[0], nil
}

func updateLoad(f *bf.File) {
	for _, s := range f.Stmt {
		call, ok := s.(*bf.CallExpr)
		if !ok || len(call.List) == 0 {
			continue
		}
		if x, ok := call.X.(*bf.LiteralExpr); !ok || x.Token != "load" {
			continue
		}
		if label, ok := call.List[0].(*bf.StringExpr); !ok || label.Value != "@io_bazel_rules_go//go:def.bzl" {
			continue
		}
		haveGoRepository := false
		for _, arg := range call.List[1:] {
			if sym, ok := arg.(*bf.StringExpr); ok && sym.Value == "go_repository" {
				haveGoRepository = true
				break
			}
		}
		if !haveGoRepository {
			call.List = append(call.List, &bf.StringExpr{Value: "go_repository"})
		}
	}
}
