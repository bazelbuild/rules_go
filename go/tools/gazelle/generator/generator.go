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

// Package generator provides core functionality of
// BUILD file generation in gazelle.
package generator

import (
	"fmt"
	"go/build"
	"path/filepath"
	"strings"

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
)

// Generator generates BUILD files for a Go repository.
type Generator struct {
	repoRoot string
	bctx     build.Context
	g        rules.Generator
}

// New returns a new Generator which is responsible for a Go repository.
//
// "repoRoot" is a path to the root directory of the repository.
// "goPrefix" is the go_prefix corresponding to the repository root directory.
// See also https://github.com/bazelbuild/rules_go#go_prefix.
func New(repoRoot, goPrefix string) (*Generator, error) {
	bctx := build.Default
	// Ignore source files in $GOROOT and $GOPATH
	bctx.GOROOT = ""
	bctx.GOPATH = ""

	repoRoot, err := filepath.Abs(repoRoot)
	if err != nil {
		return nil, err
	}
	return &Generator{
		repoRoot: filepath.Clean(repoRoot),
		bctx:     bctx,
		g:        rules.NewGenerator(goPrefix),
	}, nil
}

// Generate generates a BUILD file for each Go package found under
// the given directory.
// The directory must be the repository root directory the caller
// passed to New, or its subdirectory.
func (g *Generator) Generate(dir string) ([]*bzl.File, error) {
	dir, err := filepath.Abs(dir)
	if err != nil {
		return nil, err
	}
	dir = filepath.Clean(dir)
	if !isDescendingDir(dir, g.repoRoot) {
		return nil, fmt.Errorf("dir %s is not under the repository root %s", dir, g.repoRoot)
	}

	var files []*bzl.File
	err = packages.Walk(g.bctx, dir, func(pkg *build.Package) error {
		rel, err := filepath.Rel(g.repoRoot, pkg.Dir)
		if err != nil {
			return err
		}
		if rel == "." {
			rel = ""
		}

		rs, err := g.g.Generate(filepath.ToSlash(rel), pkg)
		if err != nil {
			return err
		}
		file := &bzl.File{Path: filepath.Join(rel, "BUILD")}
		for _, r := range rs {
			file.Stmt = append(file.Stmt, r.Call)
		}
		files = append(files, file)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return files, nil
}

func isDescendingDir(dir, root string) bool {
	if dir == root {
		return true
	}
	return strings.HasPrefix(dir, fmt.Sprintf("%s%c", root, filepath.Separator))
}
