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

	bzl "github.com/bazelbuild/buildifier/build"
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
	repoRoot := filepath.Join(testdata.Dir(), "repo")
	g := rules.NewGenerator(repoRoot, "example.com/repo", rules.External)
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
						"asm.s",
            "asm.h",
					],
					visibility = ["//visibility:public"],
					deps = ["//lib/internal/deep:go_default_library"],
				)

				go_test(
					name = "go_default_test",
					srcs = ["lib_test.go"],
					library = ":go_default_library",
				)

				go_test(
					name = "go_default_xtest",
					srcs = ["lib_external_test.go"],
					deps = [":go_default_library"],
				)
			`,
		},
		{
			dir: "lib/internal/deep",
			want: `
				go_library(
					name = "go_default_library",
					srcs = ["thought.go"],
					visibility = ["//lib:__subpackages__"],
				)
			`,
		},
		{
			dir: "lib/relativeimporter",
			want: `
				go_library(
					name = "go_default_library",
					srcs = ["importer.go"],
					visibility = ["//visibility:public"],
					deps = ["//lib/internal/deep:go_default_library"],
				)
			`,
		},
		{
			dir: "bin",
			want: `
				go_library(
					name = "go_default_library",
					srcs = ["main.go"],
					visibility = ["//visibility:private"],
					deps = ["//lib:go_default_library"],
				)

				go_binary(
					name = "bin",
					library = ":go_default_library",
					visibility = ["//visibility:public"],
				)
			`,
		},
		{
			dir: "bin_with_tests",
			want: `
				go_library(
					name = "go_default_library",
					srcs = ["main.go"],
					visibility = ["//visibility:private"],
					deps = ["//lib:go_default_library"],
				)

				go_binary(
					name = "bin_with_tests",
					library = ":go_default_library",
					visibility = ["//visibility:public"],
				)

				go_test(
					name = "go_default_test",
					srcs = ["bin_test.go"],
					library = ":go_default_library",
				)
			`,
		},
		{
			dir: "cgolib",
			want: `
				cgo_library(
					name = "cgo_default_library",
					srcs = [
						"foo.go",
						"foo.c",
						"foo.h",
						"asm.S",
					],
					copts = ["-I/weird/path"],
					clinkopts = ["-lweird"],
					visibility = ["//visibility:private"],
					deps = [
						"//lib:go_default_library",
						"//lib/deep:go_default_library",
					],
				)

				go_library(
					name = "go_default_library",
					srcs = ["pure.go"],
					library = ":cgo_default_library",
					visibility = ["//visibility:public"],
					deps = [
						"//lib:go_default_library",
						"//lib/deep:go_default_library",
					],
				)

				go_test(
					name = "go_default_test",
					srcs = ["foo_test.go"],
					library = ":go_default_library",
				)
			`},
		{
			dir: "allcgolib",
			want: `
				cgo_library(
					name = "cgo_default_library",
					srcs = [
						"foo.go",
						"foo.c",
					],
					visibility = ["//visibility:private"],
					deps = ["//lib:go_default_library"],
				)

				go_library(
					name = "go_default_library",
					library = ":cgo_default_library",
					visibility = ["//visibility:public"],
					deps = ["//lib:go_default_library"],
				)

				go_test(
					name = "go_default_test",
					srcs = ["foo_test.go"],
					library = ":go_default_library",
				)
			`},
		{
			dir: "tests_with_testdata",
			want: `
				go_test(
					name = "go_default_test",
					srcs = ["internal_test.go"],
					data = glob(["testdata/**"]),
				)

				go_test(
					name = "go_default_xtest",
					srcs = ["external_test.go"],
					data = glob(["testdata/**"]),
				)
			`},
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
