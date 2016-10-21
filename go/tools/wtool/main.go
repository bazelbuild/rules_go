/*wtool augments your bazel WORKSPACE file with new_go_repository entries

Example Usage: wtool com_github_golang_glog com_google_cloud_go
will add 2 new_go_repository to your WORKSPACE
by converting com_github_golang_glog -> github.com/golang/glog
and so forth and then doing a 'git ls-remote' to get
the latest commit.

if wtool cannot figure out the bazel -> Go mapping, try
Other Usage: wtool -asis github.com/golang/glog
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

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/wspace"
	"golang.org/x/tools/go/vcs"
)

var (
	asis = flag.Bool("asis", false, "if true, leave the import names as-is (by default they are treated as bazel converted names like org_golang_x_net")
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
	f, err := bzl.Parse(p, b)
	if err != nil {
		return err
	}
	for _, arg := range args {
		imp, err := findImport(arg)
		if err != nil {
			return err
		}
		f.Stmt = append(f.Stmt, imp)
	}
	bzl.Rewrite(f, nil)
	return ioutil.WriteFile(f.Path, bzl.Format(f), 0644)
}

func nameAndImportpath(name string) (string, string, error) {
	if *asis {
		return rules.ImportPathToBazelRepoName(name), name, nil
	}
	s := strings.Split(name, "_")
	if len(s) < 4 {
		return "", "", fmt.Errorf("only 4-part strings supported: %q", name)
	}
	rest := strings.Join(s[3:], "-")
	if strings.HasPrefix(name, "org_golang_google") {
		return name, "google.golang.org/" + rest, nil
	}
	if strings.HasPrefix(name, "com_google_cloud") {
		return name, "cloud.google.com/" + rest, nil
	}
	return name, strings.Join([]string{s[1] + "." + s[0], s[2], rest}, "/"), nil
}

func findImport(nameIn string) (bzl.Expr, error) {
	name, importpath, err := nameAndImportpath(nameIn)
	if err != nil {
		return nil, err
	}
	log.Printf(importpath)
	r, err := vcs.RepoRootForImportPath(importpath, false)
	if err != nil {
		return nil, err
	}
	if r.VCS.Cmd != "git" {
		return nil, fmt.Errorf("only git supported, not %q", r.VCS.Cmd)
	}
	commit, err := lsRemote(r.Repo)
	if err != nil {
		return nil, err
	}
	return &bzl.CallExpr{
		X: &bzl.LiteralExpr{Token: "new_go_repository"},
		List: []bzl.Expr{
			binExpr("name", name),
			binExpr("importpath", importpath),
			binExpr("commit", commit),
		},
	}, nil
}

func binExpr(key, val string) *bzl.BinaryExpr {
	return &bzl.BinaryExpr{
		X:  &bzl.LiteralExpr{Token: key},
		Op: "=",
		Y:  &bzl.StringExpr{Value: val},
	}
}

func lsRemote(repo string) (string, error) {
	cmd := exec.Command("git", "ls-remote", repo)
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
	log.Printf(b.Text())
	go cmd.Wait()
	return strings.Split(b.Text(), "\t")[0], nil
}
