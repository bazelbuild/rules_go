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

package rules_test

import (
	"io/ioutil"
	"path/filepath"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/testdata"
)

func format(rules []*bzl.Rule) string {
	var f bzl.File
	for _, r := range rules {
		f.Stmt = append(f.Stmt, r.Call)
	}
	return string(bzl.Format(&f))
}

func testConfig(repoRoot, goPrefix string) *config.Config {
	c := &config.Config{
		RepoRoot:    repoRoot,
		GoPrefix:    goPrefix,
		GenericTags: config.BuildTags{},
		Platforms:   config.DefaultPlatformTags,
	}
	c.PreprocessTags()
	return c
}

func packageFromDir(c *config.Config, dir string) *packages.Package {
	var pkg *packages.Package
	packages.Walk(c, dir, func(p *packages.Package) {
		if p.Dir == dir {
			pkg = p
		}
	})
	return pkg
}

func TestGenerator(t *testing.T) {
	repoRoot := filepath.Join(testdata.Dir(), "repo")
	goPrefix := "example.com/repo"
	c := testConfig(repoRoot, goPrefix)
	g := rules.NewGenerator(c)
	for _, rel := range []string{
		"allcgolib",
		"bin",
		"bin_with_tests",
		"cgolib",
		"cgolib_with_build_tags",
		"lib",
		"lib/internal/deep",
		"main_test_only",
		"platforms",
		"tests_import_testdata",
		"tests_with_testdata",
	} {
		dir := filepath.Join(repoRoot, filepath.FromSlash(rel))
		pkg := packageFromDir(c, dir)
		rules := g.Generate(rel, pkg)
		got := format(rules)

		wantPath := filepath.Join(pkg.Dir, "BUILD.want")
		wantBytes, err := ioutil.ReadFile(wantPath)
		if err != nil {
			t.Errorf("error reading %s: %v", wantPath, err)
			continue
		}
		want := string(wantBytes)

		if got != want {
			t.Errorf("g.Generate(%q, %#v) = %s; want %s", rel, pkg, got, want)
		}
	}
}

func TestGeneratorGoPrefix(t *testing.T) {
	repoRoot := filepath.Join(testdata.Dir(), "repo")
	goPrefix := "example.com/repo/lib"
	c := testConfig(repoRoot, goPrefix)
	g := rules.NewGenerator(c)
	dir := filepath.Join(repoRoot, "lib")
	pkg := packageFromDir(c, dir)
	rules := g.Generate("", pkg)

	if got, want := len(rules), 1; got < want {
		t.Errorf("len(rules) < %d; want >= %d", got, want)
		return
	}

	p := rules[0].Call
	if got, want := bzl.FormatString(p), `go_prefix("example.com/repo/lib")`; got != want {
		t.Errorf("r = %q; want %q", got, want)
	}
}
