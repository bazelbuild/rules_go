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
	"path"
	"path/filepath"
	"strings"

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/generator"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/merger"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/wspace"
)

var (
	buildFileName  = flag.String("build_file_name", "BUILD", "name of output build files to generate.")
	buildTags      = flag.String("build_tags", "", "comma-separated list of build tags. If not specified, GOOS and GOARCH are used.")
	external       = flag.String("external", "external", "external: resolve external packages with new_go_repository\n\tvendored: resolve external packages as packages in vendor/")
	goPrefix       = flag.String("go_prefix", "", "go_prefix of the target workspace")
	repoRoot       = flag.String("repo_root", "", "path to a directory which corresponds to go_prefix, otherwise gazelle searches for it.")
	mode           = flag.String("mode", "fix", "print: prints all of the updated BUILD files\n\tfix: rewrites all of the BUILD files in place\n\tdiff: computes the rewrite but then just does a diff")
	buildFileNames = []string{"BUILD.bazel", "BUILD"}
)

func init() {
	// See also #135.
	// TODO(yugui): Remove this flag when we drop support of Bazel 0.3.2
	flag.StringVar(&generator.GoRulesBzl, "go_rules_bzl_only_for_internal_use", "@io_bazel_rules_go//go:def.bzl", "hacky flag to build rules_go repository itself")
}

var externalResolverFromName = map[string]rules.ExternalResolver{
	"external": rules.External,
	"vendored": rules.Vendored,
}

var modeFromName = map[string]func(*bzl.File) error{
	"print": printFile,
	"fix":   fixFile,
	"diff":  diffFile,
}

func isValidBuildFileName(buildFileName string) bool {
	for _, bfn := range buildFileNames {
		if buildFileName == bfn {
			return true
		}
	}
	return false
}

func run(dirs []string, emit func(*bzl.File) error, external rules.ExternalResolver) error {
	g, err := generator.New(*repoRoot, *goPrefix, *buildFileName, *buildTags, external)
	if err != nil {
		return err
	}

	for _, d := range dirs {
		files, err := g.Generate(d)
		if err != nil {
			return err
		}
		for _, f := range files {
			f.Path = filepath.Join(*repoRoot, f.Path)
			existingFilePath, err := findBuildFile(path.Dir(f.Path))
			if os.IsNotExist(err) {
				// No existing file, so write a new one
				bzl.Rewrite(f, nil) // have buildifier 'format' our rules.
				if err := emit(f); err != nil {
					return err
				}
				continue
			}
			if err != nil {
				// An unexpected error
				return err
			}
			// Existing file, so merge and maybe remove the old one
			if f, err = merger.MergeWithExisting(f, existingFilePath); err != nil {
				return err
			}
			bzl.Rewrite(f, nil) // have buildifier 'format' our rules.
			if err := emit(f); err != nil {
				return err
			}
			if f.Path != existingFilePath {
				if err := os.Remove(existingFilePath); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage: gazelle [flags...] [package-dirs...]

Gazel is a BUILD file generator for Go projects.

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
	flag.PrintDefaults()
}

func main() {
	flag.Usage = usage
	flag.Parse()

	if *repoRoot == "" {
		var err error
		if *repoRoot, err = repo(flag.Args()); err != nil {
			log.Fatal(err)
		}
	}
	if *goPrefix == "" {
		var err error
		if *goPrefix, err = loadGoPrefix(*repoRoot); err != nil {
			if !os.IsNotExist(err) {
				log.Fatal(err)
			}
			log.Fatalf("-go_prefix not set and no root BUILD file found")
		}
	}

	if !isValidBuildFileName(*buildFileName) {
		log.Fatalf("invalid build file name %q, valid names are %s", *buildFileName, strings.Join(buildFileNames, ", "))
	}

	emit := modeFromName[*mode]
	if emit == nil {
		log.Fatalf("unrecognized mode %s", *mode)
	}

	er, ok := externalResolverFromName[*external]
	if !ok {
		log.Fatalf("unrecognized external resolver %s", *external)
	}

	args := flag.Args()
	if len(args) == 0 {
		args = append(args, ".")
	}

	if err := run(args, emit, er); err != nil {
		log.Fatal(err)
	}
}

func findBuildFile(repo string) (string, error) {
	for _, base := range buildFileNames {
		p := filepath.Join(repo, base)
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

func loadGoPrefix(repo string) (string, error) {
	p, err := findBuildFile(repo)
	if err != nil {
		return "", err
	}
	b, err := ioutil.ReadFile(p)
	if err != nil {
		return "", err
	}
	f, err := bzl.Parse(p, b)
	if err != nil {
		return "", err
	}
	for _, s := range f.Stmt {
		c, ok := s.(*bzl.CallExpr)
		if !ok {
			continue
		}
		l, ok := c.X.(*bzl.LiteralExpr)
		if !ok {
			continue
		}
		if l.Token != "go_prefix" {
			continue
		}
		if len(c.List) != 1 {
			return "", fmt.Errorf("found go_prefix(%v) with too many args", c.List)
		}
		v, ok := c.List[0].(*bzl.StringExpr)
		if !ok {
			return "", fmt.Errorf("found go_prefix(%v) which is not a string", c.List)
		}
		return v.Value, nil
	}
	return "", errors.New("-go_prefix not set, and no go_prefix in root BUILD file")
}

func repo(args []string) (string, error) {
	if len(args) == 1 {
		return args[0], nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	r, err := wspace.Find(cwd)
	if err != nil {
		return "", fmt.Errorf("-repo_root not specified, and WORKSPACE cannot be found: %v", err)
	}
	return r, nil
}
