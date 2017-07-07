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
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/wspace"
)

type emitFunc func(*config.Config, *bf.File) error

var modeFromName = map[string]emitFunc{
	"print": printFile,
	"fix":   fixFile,
	"diff":  diffFile,
}

func run(c *config.Config, emit emitFunc) {
	r := rules.NewLabelResolver(c)
	shouldProcessRoot := false
	didProcessRoot := false
	for _, dir := range c.Dirs {
		if c.RepoRoot == dir {
			shouldProcessRoot = true
		}
		packages.Walk(c, dir, func(pkg *packages.Package, oldFile *bf.File) {
			if pkg.Rel == "" {
				didProcessRoot = true
			}
			processPackage(c, r, emit, pkg, oldFile)
		})
	}
	if shouldProcessRoot && !didProcessRoot {
		// We did not process a package at the repository root. We need to put
		// a go_prefix rule there, even if there are no .go files in that directory.
		pkg := &packages.Package{Dir: c.RepoRoot}
		var oldFile *bf.File
		var oldData []byte
		oldPath, err := findBuildFile(c, c.RepoRoot)
		if os.IsNotExist(err) {
			goto processRoot
		}
		if err != nil {
			log.Print(err)
			return
		}
		oldData, err = ioutil.ReadFile(oldPath)
		if err != nil {
			log.Print(err)
			return
		}
		oldFile, err = bf.Parse(oldPath, oldData)
		if err != nil {
			log.Print(err)
			return
		}

	processRoot:
		processPackage(c, r, emit, pkg, oldFile)
	}
}

func processPackage(c *config.Config, r rules.LabelResolver, emit emitFunc, pkg *packages.Package, oldFile *bf.File) {
	g := rules.NewGenerator(c, r, oldFile)
	genFile := g.Generate(pkg)

	if oldFile == nil {
		// No existing file, so no merge required.
		rules.SortLabels(genFile)
		bf.Rewrite(genFile, nil) // have buildifier 'format' our rules.
		if err := emit(c, genFile); err != nil {
			log.Print(err)
		}
		return
	}

	// Existing file, so merge and replace the old one.
	mergedFile := merger.MergeWithExisting(genFile, oldFile)
	if mergedFile == nil {
		// Ignored file. Don't emit.
		return
	}

	rules.SortLabels(mergedFile)
	bf.Rewrite(mergedFile, nil) // have buildifier 'format' our rules.
	if err := emit(c, mergedFile); err != nil {
		log.Print(err)
		return
	}
}

func usage(fs *flag.FlagSet) {
	fmt.Fprintln(os.Stderr, `usage: gazelle [flags...] [package-dirs...]

Gazelle is a BUILD file generator for Go projects.

Currently its primary usage is to generate BUILD files for external dependencies
in a go_repository rule.
You can still use Gazelle for other purposes, but its interface can change without
notice.

It takes a list of paths to Go package directories [defaults to . if none given].
It recursively traverses its subpackages.
All the directories must be under the directory specified in -repo_root.
[if -repo_root is not given, gazelle searches $pwd and up for the WORKSPACE file]

There are several modes of gazelle.
In print mode, gazelle prints reconciled BUILD files to stdout.
In fix mode, gazelle creates BUILD files or updates existing ones.
In diff mode, gazelle shows diff.

FLAGS:
`)
	fs.PrintDefaults()
}

func main() {
	log.SetPrefix("gazelle: ")
	log.SetFlags(0) // don't print timestamps

	c, emit, err := newConfiguration(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}

	run(c, emit)
}

func newConfiguration(args []string) (*config.Config, emitFunc, error) {
	fs := flag.NewFlagSet("gazelle", flag.ContinueOnError)
	// Flag will call this on any parse error. Don't print usage unless
	// -h or -help were passed explicitly.
	fs.Usage = func() {}

	buildFileName := fs.String("build_file_name", "BUILD.bazel,BUILD", "comma-separated list of valid build file names.\nThe first element of the list is the name of output build files to generate.")
	buildTags := fs.String("build_tags", "", "comma-separated list of build tags. If not specified, Gazelle will not\n\tfilter sources with build constraints.")
	external := fs.String("external", "external", "external: resolve external packages with go_repository\n\tvendored: resolve external packages as packages in vendor/")
	goPrefix := fs.String("go_prefix", "", "go_prefix of the target workspace")
	repoRoot := fs.String("repo_root", "", "path to a directory which corresponds to go_prefix, otherwise gazelle searches for it.")
	mode := fs.String("mode", "fix", "print: prints all of the updated BUILD files\n\tfix: rewrites all of the BUILD files in place\n\tdiff: computes the rewrite but then just does a diff")
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
			return nil, nil, err
		}
	}

	if *repoRoot != "" {
		c.RepoRoot = *repoRoot
	} else if len(c.Dirs) == 1 {
		c.RepoRoot, err = wspace.Find(c.Dirs[0])
		if err != nil {
			return nil, nil, fmt.Errorf("-repo_root not specified, and WORKSPACE cannot be found: %v", err)
		}
	} else {
		cwd, err := filepath.Abs(".")
		if err != nil {
			return nil, nil, err
		}
		c.RepoRoot, err = wspace.Find(cwd)
		if err != nil {
			return nil, nil, fmt.Errorf("-repo_root not specified, and WORKSPACE cannot be found: %v", err)
		}
	}

	for _, dir := range c.Dirs {
		if !isDescendingDir(dir, c.RepoRoot) {
			return nil, nil, fmt.Errorf("dir %q is not a subdirectory of repo root %q", dir, c.RepoRoot)
		}
	}

	c.ValidBuildFileNames = strings.Split(*buildFileName, ",")
	if len(c.ValidBuildFileNames) == 0 {
		return nil, nil, fmt.Errorf("no valid build file names specified")
	}

	c.GenericTags = make(config.BuildTags)
	for _, t := range strings.Split(*buildTags, ",") {
		if strings.HasPrefix(t, "!") {
			return nil, nil, fmt.Errorf("build tags can't be negated: %s", t)
		}
		c.GenericTags[t] = true
	}
	c.Platforms = config.DefaultPlatformTags
	c.PreprocessTags()

	c.GoPrefix = *goPrefix
	if c.GoPrefix == "" {
		c.GoPrefix, err = loadGoPrefix(&c)
		if err != nil {
			return nil, nil, fmt.Errorf("-go_prefix not set and not root BUILD file found")
		}
	}

	c.DepMode, err = config.DependencyModeFromString(*external)
	if err != nil {
		return nil, nil, err
	}

	emit, ok := modeFromName[*mode]
	if !ok {
		return nil, nil, fmt.Errorf("unrecognized emit mode: %q", *mode)
	}

	return &c, emit, err
}

func findBuildFile(c *config.Config, dir string) (string, error) {
	for _, base := range c.ValidBuildFileNames {
		p := filepath.Join(dir, base)
		fi, err := os.Stat(p)
		if err == nil {
			if fi.Mode().IsRegular() {
				return p, nil
			}
			continue
		}
		if !os.IsNotExist(err) {
			return "", err
		}
	}
	return "", os.ErrNotExist
}

func loadGoPrefix(c *config.Config) (string, error) {
	p, err := findBuildFile(c, c.RepoRoot)
	if err != nil {
		return "", err
	}
	b, err := ioutil.ReadFile(p)
	if err != nil {
		return "", err
	}
	f, err := bf.Parse(p, b)
	if err != nil {
		return "", err
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
			return "", fmt.Errorf("found go_prefix(%v) with too many args", c.List)
		}
		v, ok := c.List[0].(*bf.StringExpr)
		if !ok {
			return "", fmt.Errorf("found go_prefix(%v) which is not a string", c.List)
		}
		return v.Value, nil
	}
	return "", errors.New("-go_prefix not set, and no go_prefix in root BUILD file")
}

func isDescendingDir(dir, root string) bool {
	if dir == root {
		return true
	}
	return strings.HasPrefix(dir, fmt.Sprintf("%s%c", root, filepath.Separator))
}
