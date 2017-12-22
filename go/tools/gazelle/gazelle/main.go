/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Command gazelle is a BUILD file generator for Go projects.
// See "gazelle --help" for more details.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/merger"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/resolve"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/wspace"
)

type emitFunc func(*config.Config, *bf.File) error

var modeFromName = map[string]emitFunc{
	"print": printFile,
	"fix":   fixFile,
	"diff":  diffFile,
}

type command int

const (
	updateCmd command = iota
	fixCmd
)

var commandFromName = map[string]command{
	"update": updateCmd,
	"fix":    fixCmd,
}

// visitRecord stores information about about a directory visited with
// packages.Walk.
type visitRecord struct {
	// pkgRel is the slash-separated path to the visited directory, relative to
	// the repository root. "" for the repository root itself.
	pkgRel string

	// rules is a list of generated Go rules.
	rules []bf.Expr

	// empty is a list of empty Go rules that may be deleted.
	empty []bf.Expr

	// file is the build file being processed.
	file *bf.File
}

type byPkgRel []visitRecord

func (vs byPkgRel) Len() int           { return len(vs) }
func (vs byPkgRel) Less(i, j int) bool { return vs[i].pkgRel < vs[j].pkgRel }
func (vs byPkgRel) Swap(i, j int)      { vs[i], vs[j] = vs[j], vs[i] }

func run(c *config.Config, cmd command, emit emitFunc) {
	shouldFix := c.ShouldFix
	l := resolve.NewLabeler(c)
	ruleIndex := resolve.NewRuleIndex()

	var visits []visitRecord

	// Visit all directories in the repository.
	packages.Walk(c, c.RepoRoot, func(rel string, c *config.Config, pkg *packages.Package, file *bf.File, isUpdateDir bool) {
		if file != nil {
			// Fix files in update directories.
			if isUpdateDir {
				file = merger.FixFileMinor(c, file)
				if shouldFix {
					file = merger.FixFile(c, file)
				} else {
					fixedFile := merger.FixFile(c, file)
					if fixedFile != file {
						log.Printf("%s: warning: file contains rules whose structure is out of date. Consider running 'gazelle fix'.", file.Path)
					}
				}
			}

			// Index existing rules.
			ruleIndex.AddRulesFromFile(c, file)
		}

		// TODO(#939): delete rules in directories where pkg == nil (no buildable
		// Go code).
		if !isUpdateDir {
			return
		}

		// Generate rules.
		if pkg != nil {
			g := rules.NewGenerator(c, l, file)
			rules, empty, err := g.GenerateRules(pkg)
			if err != nil {
				log.Print(err)
				return
			}
			file, rules = merger.MergeFile(rules, empty, file, merger.MergeableGeneratedAttrs)
			if file == nil {
				return
			}
			if file.Path == "" {
				file.Path = filepath.Join(c.RepoRoot, filepath.FromSlash(rel), c.DefaultBuildFileName())
			}
			ruleIndex.AddGeneratedRules(c, rel, rules)
			visits = append(visits, visitRecord{
				pkgRel: rel,
				rules:  rules,
				empty:  empty,
				file:   file,
			})
		}
	})

	// Finish building the index for dependency resolution.
	ruleIndex.Finish()

	// Resolve dependencies.
	resolver := resolve.NewResolver(c, l, ruleIndex)
	for i := range visits {
		for j := range visits[i].rules {
			visits[i].rules[j] = resolver.ResolveRule(visits[i].rules[j], visits[i].pkgRel)
		}
		visits[i].file, _ = merger.MergeFile(visits[i].rules, visits[i].empty, visits[i].file, merger.MergeableResolvedAttrs)
	}

	// Emit merged files.
	for _, v := range visits {
		rules.SortLabels(v.file)
		v.file = merger.FixLoads(v.file)
		bf.Rewrite(v.file, nil) // have buildifier 'format' our rules.
		if err := emit(c, v.file); err != nil {
			log.Print(err)
		}
	}
}

func usage(fs *flag.FlagSet) {
	fmt.Fprintln(os.Stderr, `usage: gazelle <command> [flags...] [package-dirs...]

Gazelle is a BUILD file generator for Go projects. It can create new BUILD files
for a project that follows "go build" conventions, and it can update BUILD files
if they already exist. It can be invoked directly in a project workspace, or
it can be run on an external dependency during the build as part of the
go_repository rule.

Gazelle may be run with one of the commands below. If no command is given,
Gazelle defaults to "update".

  update - Gazelle will create new BUILD files or update existing BUILD files
      if needed.
	fix - in addition to the changes made in update, Gazelle will make potentially
	    breaking changes. For example, it may delete obsolete rules or rename
      existing rules.

Gazelle has several output modes which can be selected with the -mode flag. The
output mode determines what Gazelle does with updated BUILD files.

  fix (default) - write updated BUILD files back to disk.
  print - print updated BUILD files to stdout.
  diff - diff updated BUILD files against existing files in unified format.

Gazelle accepts a list of paths to Go package directories to process (defaults
to . if none given). It recursively traverses subdirectories. All directories
must be under the directory specified by -repo_root; if -repo_root is not given,
this is the directory containing the WORKSPACE file.

Gazelle is under active delevopment, and its interface may change
without notice.

FLAGS:
`)
	fs.PrintDefaults()
}

func main() {
	log.SetPrefix("gazelle: ")
	log.SetFlags(0) // don't print timestamps

	c, cmd, emit, err := newConfiguration(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}

	run(c, cmd, emit)
}

func newConfiguration(args []string) (*config.Config, command, emitFunc, error) {
	cmd := updateCmd
	if len(args) > 0 {
		if c, ok := commandFromName[args[0]]; ok {
			cmd = c
			args = args[1:]
		}
	}

	fs := flag.NewFlagSet("gazelle", flag.ContinueOnError)
	// Flag will call this on any parse error. Don't print usage unless
	// -h or -help were passed explicitly.
	fs.Usage = func() {}

	knownImports := multiFlag{}
	buildFileName := fs.String("build_file_name", "BUILD.bazel,BUILD", "comma-separated list of valid build file names.\nThe first element of the list is the name of output build files to generate.")
	buildTags := fs.String("build_tags", "", "comma-separated list of build tags. If not specified, Gazelle will not\n\tfilter sources with build constraints.")
	external := fs.String("external", "external", "external: resolve external packages with go_repository\n\tvendored: resolve external packages as packages in vendor/")
	var goPrefix explicitFlag
	fs.Var(&goPrefix, "go_prefix", "prefix of import paths in the current workspace")
	repoRoot := fs.String("repo_root", "", "path to a directory which corresponds to go_prefix, otherwise gazelle searches for it.")
	fs.Var(&knownImports, "known_import", "import path for which external resolution is skipped (can specify multiple times)")
	mode := fs.String("mode", "fix", "print: prints all of the updated BUILD files\n\tfix: rewrites all of the BUILD files in place\n\tdiff: computes the rewrite but then just does a diff")
	proto := fs.String("proto", "default", "default: generates new proto rules\n\tdisable: does not touch proto rules\n\tlegacy (deprecated): generates old proto rules")
	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			usage(fs)
			os.Exit(0)
		}
		// flag already prints the error; don't print it again.
		log.Fatal("Try -help for more information.")
	}

	var c config.Config
	var err error

	c.Dirs = fs.Args()
	if len(c.Dirs) == 0 {
		c.Dirs = []string{"."}
	}
	for i := range c.Dirs {
		c.Dirs[i], err = filepath.Abs(c.Dirs[i])
		if err != nil {
			return nil, cmd, nil, err
		}
	}

	if *repoRoot != "" {
		c.RepoRoot = *repoRoot
	} else if len(c.Dirs) == 1 {
		c.RepoRoot, err = wspace.Find(c.Dirs[0])
		if err != nil {
			return nil, cmd, nil, fmt.Errorf("-repo_root not specified, and WORKSPACE cannot be found: %v", err)
		}
	} else {
		cwd, err := filepath.Abs(".")
		if err != nil {
			return nil, cmd, nil, err
		}
		c.RepoRoot, err = wspace.Find(cwd)
		if err != nil {
			return nil, cmd, nil, fmt.Errorf("-repo_root not specified, and WORKSPACE cannot be found: %v", err)
		}
	}

	for _, dir := range c.Dirs {
		if !isDescendingDir(dir, c.RepoRoot) {
			return nil, cmd, nil, fmt.Errorf("dir %q is not a subdirectory of repo root %q", dir, c.RepoRoot)
		}
	}

	c.ValidBuildFileNames = strings.Split(*buildFileName, ",")
	if len(c.ValidBuildFileNames) == 0 {
		return nil, cmd, nil, fmt.Errorf("no valid build file names specified")
	}

	c.SetBuildTags(*buildTags)
	c.PreprocessTags()

	if goPrefix.set {
		c.GoPrefix = goPrefix.value
	} else {
		c.GoPrefix, err = loadGoPrefix(&c)
		if err != nil {
			return nil, cmd, nil, err
		}
	}
	if err := config.CheckPrefix(c.GoPrefix); err != nil {
		return nil, cmd, nil, err
	}

	c.ShouldFix = cmd == fixCmd

	c.DepMode, err = config.DependencyModeFromString(*external)
	if err != nil {
		return nil, cmd, nil, err
	}

	c.ProtoMode, err = config.ProtoModeFromString(*proto)
	if err != nil {
		return nil, cmd, nil, err
	}

	emit, ok := modeFromName[*mode]
	if !ok {
		return nil, cmd, nil, fmt.Errorf("unrecognized emit mode: %q", *mode)
	}

	c.KnownImports = append(c.KnownImports, knownImports...)

	return &c, cmd, emit, err
}

type explicitFlag struct {
	set   bool
	value string
}

func (f *explicitFlag) Set(value string) error {
	f.set = true
	f.value = value
	return nil
}

func (f *explicitFlag) String() string {
	if f == nil {
		return ""
	}
	return f.value
}

func loadBuildFile(c *config.Config, dir string) (*bf.File, error) {
	var buildPath string
	for _, base := range c.ValidBuildFileNames {
		p := filepath.Join(dir, base)
		fi, err := os.Stat(p)
		if err == nil {
			if fi.Mode().IsRegular() {
				buildPath = p
				break
			}
			continue
		}
		if !os.IsNotExist(err) {
			return nil, err
		}
	}
	if buildPath == "" {
		return nil, os.ErrNotExist
	}

	data, err := ioutil.ReadFile(buildPath)
	if err != nil {
		return nil, err
	}
	return bf.Parse(buildPath, data)
}

func loadGoPrefix(c *config.Config) (string, error) {
	f, err := loadBuildFile(c, c.RepoRoot)
	if err != nil {
		return "", errors.New("-go_prefix not set")
	}
	for _, d := range config.ParseDirectives(f) {
		if d.Key == "prefix" {
			return d.Value, nil
		}
	}
	for _, s := range f.Stmt {
		c, ok := s.(*bf.CallExpr)
		if !ok {
			continue
		}
		l, ok := c.X.(*bf.LiteralExpr)
		if !ok {
			continue
		}
		if l.Token != "go_prefix" {
			continue
		}
		if len(c.List) != 1 {
			return "", fmt.Errorf("-go_prefix not set, and %s has go_prefix(%v) with too many args", f.Path, c.List)
		}
		v, ok := c.List[0].(*bf.StringExpr)
		if !ok {
			return "", fmt.Errorf("-go_prefix not set, and %s has go_prefix(%v) which is not a string", f.Path, bf.FormatString(c.List[0]))
		}
		return v.Value, nil
	}
	return "", fmt.Errorf("-go_prefix not set, and no # gazelle:prefix directive found in %s", f.Path)
}

func isDescendingDir(dir, root string) bool {
	rel, err := filepath.Rel(root, dir)
	if err != nil {
		return false
	}
	if rel == "." {
		return true
	}
	return !strings.HasPrefix(rel, "..")
}
