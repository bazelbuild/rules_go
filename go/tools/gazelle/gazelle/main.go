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
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/generator"
)

var (
	goPrefix = flag.String("go_prefix", "", "go_prefix of the target workspace")
	repoRoot = flag.String("repo_root", "", "path to a directory which corresponds to go_prefix")
	mode     = flag.String("mode", "print", "print, fix or diff")
)

var modeFromName = map[string]func(*bzl.File) error{
	"print": printFile,
	"fix":   fixFile,
	"diff":  diffFile,
}

func run(dirs []string, emit func(*bzl.File) error) error {
	g, err := generator.New(*repoRoot, *goPrefix)
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
			if err := emit(f); err != nil {
				return err
			}
		}
	}
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage: gazelle [flags...] package-dir [package-dirs...]

Gazel is a BUILD file generator for Go projects.

Currently its primary usage is to generate BUILD files for external dependencies
in a go_vendor repository rule.
You can still use Gazel for other purposes, but its interface can change without
notice.

It takes a list of paths to Go package directories.
It recursively traverses its subpackages.
All the directories must be under the directory specified in -repo_root.

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

	if *goPrefix == "" {
		// TODO(yugui): Extract go_prefix from the top level BUILD file if
		// exists
		log.Fatal("-go_prefix is required")
	}
	if *repoRoot == "" {
		if flag.NArg() != 1 {
			log.Fatal("-repo_root is required")
		}
		// TODO(yugui): Guess repoRoot at the same time as goPrefix
		*repoRoot = flag.Arg(0)
	}

	emit := modeFromName[*mode]
	if emit == nil {
		log.Fatalf("unrecognized mode %s", *mode)
	}

	if len(flag.Args()) == 0 {
		log.Fatal("No package directories given, nothing to do")
	}

	if err := run(flag.Args(), emit); err != nil {
		log.Fatal(err)
	}
}
