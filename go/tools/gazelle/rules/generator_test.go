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
	"go/build"
	"io/ioutil"
	"path/filepath"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
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

func packageFromDir(t *testing.T, dir string) *build.Package {
	dir = filepath.Join(testdata.Dir(), "repo", dir)
	pkg, err := build.ImportDir(dir, build.ImportComment)
	if err != nil {
		t.Fatalf("build.ImportDir(%q, build.ImportComment) failed with %v; want success", dir, err)
	}
	return pkg
}

func TestGenerator(t *testing.T) {
	repoRoot := filepath.Join(testdata.Dir(), "repo")
	g := rules.NewGenerator(repoRoot, "example.com/repo", rules.External)
	for _, dir := range []string{
		"lib",
		"lib/internal/deep",
		"bin",
		"bin_with_tests",
		"cgolib",
		"allcgolib",
	} {
		pkg := packageFromDir(t, filepath.FromSlash(dir))
		rules, err := g.Generate(dir, pkg)
		if err != nil {
			t.Errorf("g.Generate(%q, %#v) failed with %v; want success", dir, pkg, err)
			continue
		}
		got := format(rules)

		wantPath := filepath.Join(pkg.Dir, "BUILD.want")
		wantBytes, err := ioutil.ReadFile(wantPath)
		if err != nil {
			t.Errorf("error reading %s: %v", wantPath, err)
			continue
		}
		want := string(wantBytes)

		if got != want {
			t.Errorf("g.Generate(%q, %#v) = %s; want %s", dir, pkg, got, want)
		}
	}
}

func TestGeneratorGoPrefix(t *testing.T) {
	repoRoot := filepath.Join(testdata.Dir(), "repo")
	g := rules.NewGenerator(repoRoot, "example.com/repo/lib", rules.External)
	pkg := packageFromDir(t, filepath.FromSlash("lib"))
	rules, err := g.Generate("", pkg)
	if err != nil {
		t.Errorf("g.Generate(%q, %#v) failed with %v; want success", "", pkg, err)
	}

	if got, want := len(rules), 1; got < want {
		t.Errorf("len(rules) < %d; want >= %d", got, want)
		return
	}

	p := rules[0].Call
	if got, want := bzl.FormatString(p), `go_prefix("example.com/repo/lib")`; got != want {
		t.Errorf("r = %q; want %q", got, want)
	}
}
