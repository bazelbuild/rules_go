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
	"path/filepath"
	"testing"

	bzl "github.com/bazelbuild/buildifier/core"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/rules"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/testdata"
)

func canonicalize(t *testing.T, filename, content string) string {
	f, err := bzl.Parse(filename, []byte(content))
	if err != nil {
		t.Fatalf("bzl.Parse(%q, %q) failed with %v; want success", filename, content, err)
	}
	return string(bzl.Format(f))
}

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
	g := rules.NewGenerator()
	for _, spec := range []struct {
		dir  string
		want string
	}{
		{
			dir: "lib",
			want: `
				go_library(
					name = "go_default_library",
					srcs = [
						"doc.go",
						"lib.go",
					],
				)
			`,
		},
		{
			dir: "bin",
			want: `
				go_binary(
					name = "bin",
					srcs = ["main.go"],
				)
			`,
		},
	} {
		pkg := packageFromDir(t, filepath.FromSlash(spec.dir))
		rules, err := g.Generate(spec.dir, pkg)
		if err != nil {
			t.Errorf("g.Generate(%q, %#v) failed with %v; want success", spec.dir, pkg, err)
		}

		if got, want := format(rules), canonicalize(t, spec.dir+"/BUILD", spec.want); got != want {
			t.Errorf("g.Generate(%q, %#v) = %s; want %s", spec.dir, pkg, got, want)
		}
	}
}
