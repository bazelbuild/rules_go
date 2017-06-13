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
	"path/filepath"
	"reflect"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/testdata"
)

func TestBuildTagOverride(t *testing.T) {
	repo := filepath.Join(testdata.Dir(), "repo")
	buildTags := map[string]bool{"a": true, "b": true}
	g, err := New(repo, "example.com/repo", "BUILD", buildTags, rules.External)
	if err != nil {
		t.Errorf(`New(%q, "example.com/repo") failed with %v; want success`, repo, err)
		return
	}

	expectedTags := []string{"a", "b", "cgo", "go1.8", "go1.7"}
	for _, tag := range expectedTags {
		if !g.buildTags[tag] {
			t.Errorf("tag %q not set", tag)
		}
		for name, platformTags := range g.platforms {
			if !platformTags[tag] {
				t.Errorf("on platform %q, tag %q not set", name, tag)
			}
		}
	}
}

func TestGeneratedFileName(t *testing.T) {
	testGeneratedFileName(t, "BUILD")
	testGeneratedFileName(t, "BUILD.bazel")
}

func testGeneratedFileName(t *testing.T, buildFileName string) {
	repo := filepath.Join(testdata.Dir(), "repo")
	g, err := New(repo, "example.com/repo", buildFileName, nil, rules.External)
	if err != nil {
		t.Errorf("error creating generator: %v", err)
		return
	}
	fs := g.Generate(filepath.Join(repo, "bin"))
	fs = fs[1:] // ignore empty top-level file with go_prefix
	if got, want := fs[0].Path, filepath.Join("bin", buildFileName); got != want {
		t.Errorf("got file named %q; want %q", got, want)
	}
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
