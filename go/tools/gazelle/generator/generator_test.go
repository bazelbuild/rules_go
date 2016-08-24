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

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/testdata"
)

func TestGenerator(t *testing.T) {
	stub := stubRuleGen{
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
			"bin": {
				{
					Call: &bzl.CallExpr{
						X: &bzl.LiteralExpr{Token: "go_binary"},
					},
				},
			},
		},
	}

	repo := filepath.Join(testdata.Dir(), "repo")
	g, err := New(repo, "example.com/repo")
	if err != nil {
		t.Errorf(`New(%q, "example.com/repo") failed with %v; want success`, repo, err)
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
			Path: "BUILD",
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
			Path: "lib/BUILD",
			Stmt: []bzl.Expr{
				loadExpr("go_prefix", "go_library"),
				stub.fixtures["lib"][0].Call,
				stub.fixtures["lib"][1].Call,
			},
		},
		{
			Path: "lib/internal/deep/BUILD",
			Stmt: []bzl.Expr{
				loadExpr("go_library", "go_test"),
				stub.fixtures["lib/internal/deep"][0].Call,
				stub.fixtures["lib/internal/deep"][1].Call,
			},
		},
		{
			Path: "bin/BUILD",
			Stmt: []bzl.Expr{
				loadExpr("go_binary"),
				stub.fixtures["bin"][0].Call,
			},
		},
	}
	sort.Sort(fileSlice(want))

	if !reflect.DeepEqual(got, want) {
		t.Errorf("g.Generate(%q) = %s; want %s", repo, prettyFiles(got), prettyFiles(want))
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
}

func (s stubRuleGen) Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error) {
	return s.fixtures[rel], nil
}
