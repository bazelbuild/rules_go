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

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/generator"
)

var (
	repoRoot = flag.String("repo_root", "", "path to a root directory of a repository")
)

func run(dirs []string) error {
	g, err := generator.New(*repoRoot)
	if err != nil {
		return err
	}

	for _, d := range dirs {
		files, err := g.Generate(d)
		if err != nil {
			return err
		}
		for _, f := range files {
			if _, err := os.Stdout.Write(bzl.Format(f)); err != nil {
				return err
			}
		}
	}
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage: gazelle [flags...] [package-dirs...]

Gazel is a BUILD file generator for Go projects.

Currently its primary usage is to generate BUILD files for external dependencies
in a go_vendor repository rule.
You can still use Gazel for other purposes, but its interface can change without
notice.

It takes a list of paths to Go package directories.
It recursively traverses its subpackages.
All the directories must be under the directory specified in -repo_root.

FLAGS:
`)
	flag.PrintDefaults()
}

func main() {
	flag.Usage = usage
	flag.Parse()

	if *repoRoot == "" {
		if flag.NArg() != 1 {
			log.Fatal("-repo_root is required")
		}
		*repoRoot = flag.Arg(0)
	}
	if err := run(flag.Args()); err != nil {
		log.Fatal(err)
	}
}
