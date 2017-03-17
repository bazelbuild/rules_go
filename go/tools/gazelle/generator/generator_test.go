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

package generator

import (
	"fmt"
	"go/build"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"

	bzl "github.com/bazelbuild/buildifier/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/testdata"
)

var (
	buildTagRepoPath = "cgolib_with_build_tags"
)

func TestGenerator(t *testing.T) {
	testGenerator(t, "BUILD")
}

func TestGeneratorDotBazel(t *testing.T) {
	testGenerator(t, "BUILD.bazel")
}

func TestLoadExprSorted(t *testing.T) {
	out := loadExpr("go_library", "another_thing", "sorted_last")
	expected := []string{"@io_bazel_rules_go//go:def.bzl", "another_thing", "go_library", "sorted_last"}
	var actual []string
	for _, item := range out.List {
		it, ok := item.(*bzl.StringExpr)
		if !ok {
			t.Fatalf("loadExpr List: got %T, want *bzl.StringExpr", item)
		}
		actual = append(actual, it.Value)
	}
	if !reflect.DeepEqual(actual, expected) {
		t.Errorf("loadExpr List strings: want %#v, got %#v", expected, actual)
	}
}

func testGenerator(t *testing.T, buildFileName string) {
	stub := stubRuleGen{
		goFiles: make(map[string][]string),
		cFiles:  make(map[string][]string),
		sFiles:  make(map[string][]string),
		fixtures: map[string][]*bzl.Rule{
			"lib": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_prefix"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
			},
			"lib/internal/deep": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			"lib/relativeimporter": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
			},
			"bin": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_binary"},
					},
				},
			},
			"bin_with_tests": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_binary"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			"cgolib": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "cgo_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			buildTagRepoPath: {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "cgo_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			"allcgolib": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "cgo_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			"tests_with_testdata": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_test"},
					},
				},
			},
			"lib_with_ignored_main": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_library"},
					},
				},
			},
		},
	}

	repo := filepath.Join(testdata.Dir(), "repo")
	g, err := New(repo, "example.com/repo", buildFileName, rules.External)
	if err != nil {
		t.Errorf(`New(%q, "example.com/repo", %q, "", rules.External) failed with %v; want success`, repo, err, buildFileName)
		return
	}
	g.g = stub

	got, err := g.Generate(repo)
	if err != nil {
		t.Errorf("g.Generate(%q) failed with %v; want success", repo, err)
	}
	sort.Sort(fileSlice(got))

	want := []*bzl.File{
		{
			Path: buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_prefix"),
				&bzl.CallExpr{
					X: &bzl.LiteralExpr{Token: "go_prefix"},
					List: []bzl.Expr{
						&bzl.StringExpr{Value: "example.com/repo"},
					},
				},
			},
		},
		{
			Path: "lib/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_prefix", "go_library"),
				stub.fixtures["lib"][0].Call,
				stub.fixtures["lib"][1].Call,
			},
		},
		{
			Path: "lib/internal/deep/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_test"),
				stub.fixtures["lib/internal/deep"][0].Call,
				stub.fixtures["lib/internal/deep"][1].Call,
			},
		},
		{
			Path: "lib/relativeimporter/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library"),
				stub.fixtures["lib/relativeimporter"][0].Call,
			},
		},
		{
			Path: "bin/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_binary"),
				stub.fixtures["bin"][0].Call,
				stub.fixtures["bin"][1].Call,
			},
		},
		{
			Path: "bin_with_tests/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_binary", "go_test"),
				stub.fixtures["bin_with_tests"][0].Call,
				stub.fixtures["bin_with_tests"][1].Call,
				stub.fixtures["bin_with_tests"][2].Call,
			},
		},
		{
			Path: "cgolib/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_test", "cgo_library"),
				stub.fixtures["cgolib"][0].Call,
				stub.fixtures["cgolib"][1].Call,
				stub.fixtures["cgolib"][2].Call,
			},
		},
		{
			Path: "cgolib_with_build_tags/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_test", "cgo_library"),
				stub.fixtures["cgolib_with_build_tags"][0].Call,
				stub.fixtures["cgolib_with_build_tags"][1].Call,
				stub.fixtures["cgolib_with_build_tags"][2].Call,
			},
		},
		{
			Path: "allcgolib/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_test", "cgo_library"),
				stub.fixtures["allcgolib"][0].Call,
				stub.fixtures["allcgolib"][1].Call,
				stub.fixtures["allcgolib"][2].Call,
			},
		},
		{
			Path: "tests_with_testdata/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_test"),
				stub.fixtures["tests_with_testdata"][0].Call,
				stub.fixtures["tests_with_testdata"][1].Call,
			},
		},
		{
			Path: "lib_with_ignored_main/" + buildFileName,
			Stmt: []bzl.Expr{
				loadExpr("go_library"),
				stub.fixtures["lib_with_ignored_main"][0].Call,
			},
		},
	}

	sort.Sort(fileSlice(want))

	if !reflect.DeepEqual(got, want) {
		t.Errorf("g.Generate(%q) = %s; want: %s", repo, prettyFiles(got), prettyFiles(want))
	}
}

type prettyFiles []*bzl.File

func (p prettyFiles) String() string {
	var items []string
	for _, f := range p {
		items = append(items, fmt.Sprintf("{Path: %q, Stmt: %s}", f.Path, string(bzl.Format(f))))
	}
	return fmt.Sprintf("[%s]", strings.Join(items, ","))
}

type fileSlice []*bzl.File

func (p fileSlice) Less(i, j int) bool { return strings.Compare(p[i].Path, p[j].Path) < 0 }
func (p fileSlice) Len() int           { return len(p) }
func (p fileSlice) Swap(i, j int)      { p[i], p[j] = p[j], p[i] }

// stubRuleGen is a test stub implementation of rules.Generator
type stubRuleGen struct {
	fixtures map[string][]*bzl.Rule
	goFiles  map[string][]string
	sFiles   map[string][]string
	cFiles   map[string][]string
}

func (s stubRuleGen) Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error) {
	s.goFiles[rel] = pkg.GoFiles
	s.cFiles[rel] = pkg.CFiles
	s.sFiles[rel] = pkg.SFiles
	return s.fixtures[rel], nil
}
