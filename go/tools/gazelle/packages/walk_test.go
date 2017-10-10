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

package packages_test

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
)

func tempDir() (string, error) {
	return ioutil.TempDir(os.Getenv("TEST_TMPDIR"), "walk_test")
}

type fileSpec struct {
	path, content string
}

func checkFiles(t *testing.T, files []fileSpec, goPrefix string, want []*packages.Package) {
	dir, err := createFiles(files)
	if err != nil {
		t.Fatalf("createFiles() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	for _, p := range want {
		p.Dir = filepath.Join(dir, filepath.FromSlash(p.Rel))
	}

	got := walkPackages(dir, goPrefix, dir)
	checkPackages(t, got, want)
}

func createFiles(files []fileSpec) (string, error) {
	dir, err := tempDir()
	if err != nil {
		return "", err
	}
	for _, f := range files {
		path := filepath.Join(dir, f.path)
		if strings.HasSuffix(f.path, "/") {
			if err := os.MkdirAll(path, 0700); err != nil {
				return dir, err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return "", err
		}
		if err := ioutil.WriteFile(path, []byte(f.content), 0600); err != nil {
			return "", err
		}
	}
	return dir, nil
}

func walkPackages(repoRoot, goPrefix, dir string) []*packages.Package {
	c := &config.Config{
		RepoRoot:            repoRoot,
		GoPrefix:            goPrefix,
		ValidBuildFileNames: config.DefaultValidBuildFileNames,
	}
	var pkgs []*packages.Package
	packages.Walk(c, dir, func(_ *config.Config, pkg *packages.Package, _ *bf.File) {
		pkgs = append(pkgs, pkg)
	})
	return pkgs
}

func checkPackages(t *testing.T, got []*packages.Package, want []*packages.Package) {
	if len(got) != len(want) {
		t.Fatalf("got %d packages; want %d", len(got), len(want))
	}
	for i := 0; i < len(got); i++ {
		checkPackage(t, got[i], want[i])
	}
}

func checkPackage(t *testing.T, got, want *packages.Package) {
	// TODO: Implement Stringer or Formatter to get more readable output.
	if !reflect.DeepEqual(got, want) {
		t.Errorf("for package %q, got %#v; want %#v", want.Name, got, want)
	}
}

func TestWalkEmpty(t *testing.T) {
	files := []fileSpec{
		{path: "a/foo.c"},
		{path: "b/BUILD"},
		{path: "c/"},
	}
	want := []*packages.Package{}
	checkFiles(t, files, "", want)
}

func TestWalkSimple(t *testing.T) {
	files := []fileSpec{{path: "lib.go", content: "package lib"}}
	want := []*packages.Package{
		{
			Name: "lib",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"lib.go"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestWalkNested(t *testing.T) {
	files := []fileSpec{
		{path: "a/foo.go", content: "package a"},
		{path: "b/c/bar.go", content: "package c"},
		{path: "b/d/baz.go", content: "package main"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Rel:  "a",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"foo.go"},
				},
			},
		},
		{
			Name: "c",
			Rel:  "b/c",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"bar.go"},
				},
			},
		},
		{
			Name: "main",
			Rel:  "b/d",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"baz.go"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestProtoOnly(t *testing.T) {
	files := []fileSpec{
		{path: "a/a.proto"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Rel:  "a",
			Proto: packages.ProtoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.proto"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestMultiplePackagesWithDefault(t *testing.T) {
	files := []fileSpec{
		{path: "a/a.go", content: "package a"},
		{path: "a/b.go", content: "package b"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Rel:  "a",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestMultiplePackagesWithoutDefault(t *testing.T) {
	files := []fileSpec{
		{path: "a/b.go", content: "package b"},
		{path: "a/c.go", content: "package c"},
	}
	dir, err := createFiles(files)
	if err != nil {
		t.Fatalf("createFiles() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	got := walkPackages(dir, "", dir)
	if len(got) > 0 {
		t.Errorf("got %v; want empty slice", got)
	}
}

func TestMultiplePackagesWithProtoDefault(t *testing.T) {
	files := []fileSpec{
		{path: "a/a.proto", content: `syntax = "proto2";
package a;
`},
		{path: "a/b.go", content: "package b"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Rel:  "a",
			Proto: packages.ProtoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.proto"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestRootWithPrefix(t *testing.T) {
	files := []fileSpec{
		{path: "a.go", content: "package a"},
		{path: "b.go", content: "package b"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
		},
	}
	checkFiles(t, files, "github.com/a", want)
}

func TestRootWithoutPrefix(t *testing.T) {
	files := []fileSpec{
		{path: "a.go", content: "package a"},
		{path: "b.go", content: "package b"},
	}
	dir, err := createFiles(files)
	if err != nil {
		t.Fatalf("createFiles() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	got := walkPackages(dir, "", dir)
	if len(got) > 0 {
		t.Errorf("got %v; want empty slice", got)
	}
}

func TestTestdata(t *testing.T) {
	files := []fileSpec{
		{path: "raw/testdata/"},
		{path: "raw/a.go", content: "package raw"},
		{path: "with_build/testdata/BUILD"},
		{path: "with_build/a.go", content: "package with_build"},
		{path: "with_build_bazel/testdata/BUILD.bazel"},
		{path: "with_build_bazel/a.go", content: "package with_build_bazel"},
		{path: "with_build_nested/testdata/x/BUILD"},
		{path: "with_build_nested/a.go", content: "package with_build_nested"},
		{path: "with_go/testdata/a.go", content: "package testdata"},
		{path: "with_go/a.go", content: "package with_go"},
	}
	want := []*packages.Package{
		{
			Name: "raw",
			Rel:  "raw",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
			HasTestdata: true,
		},
		{
			Name: "with_build",
			Rel:  "with_build",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
			HasTestdata: false,
		},
		{
			Name: "with_build_bazel",
			Rel:  "with_build_bazel",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
			HasTestdata: false,
		},
		{
			Name: "with_build_nested",
			Rel:  "with_build_nested",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
			HasTestdata: false,
		},
		{
			Name: "testdata",
			Rel:  "with_go/testdata",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
		},
		{
			Name: "with_go",
			Rel:  "with_go",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.go"},
				},
			},
			HasTestdata: false,
		},
	}
	checkFiles(t, files, "", want)
}

func TestGenerated(t *testing.T) {
	files := []fileSpec{
		{
			path: "gen/BUILD",
			content: `
genrule(
    name = "from_genrule",
    outs = ["foo.go", "bar.go", "w.txt", "x.c", "y.s", "z.S"],
)

gen_other(
    name = "from_gen_other",
    out = "baz.go",
)
`,
		},
		{
			path: "gen/foo.go",
			content: `package foo

import "github.com/jr_hacker/stuff"
`,
		},
	}
	want := []*packages.Package{
		{
			Name: "foo",
			Rel:  "gen",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"foo.go", "bar.go", "y.s", "baz.go"},
				},
				Imports: packages.PlatformStrings{
					Generic: []string{"github.com/jr_hacker/stuff"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestGeneratedCgo(t *testing.T) {
	files := []fileSpec{
		{
			path: "gen/BUILD",
			content: `
genrule(
    name = "from_genrule",
    outs = ["foo.go", "bar.go", "w.txt", "x.c", "y.s", "z.S"],
)

gen_other(
    name = "from_gen_other",
    out = "baz.go",
)
`,
		},
		{
			path: "gen/foo.go",
			content: `package foo

import "C"

import "github.com/jr_hacker/stuff"
`,
		},
	}
	want := []*packages.Package{
		{
			Name: "foo",
			Rel:  "gen",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"foo.go", "bar.go", "x.c", "y.s", "z.S", "baz.go"},
				},
				Imports: packages.PlatformStrings{
					Generic: []string{"github.com/jr_hacker/stuff"},
				},
				Cgo: true,
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestExcluded(t *testing.T) {
	files := []fileSpec{
		{
			path: "exclude/BUILD",
			content: `
# gazelle:exclude do.go

# gazelle:exclude not.go
# gazelle:exclude build.go

genrule(
    name = "gen_build",
    outs = ["build.go"],
)
`,
		},
		{
			path:    "exclude/do.go",
			content: "",
		},
		{
			path:    "exclude/not.go",
			content: "",
		},
		{
			path:    "exclude/build.go",
			content: "",
		},
		{
			path:    "exclude/real.go",
			content: "package exclude",
		},
	}
	want := []*packages.Package{
		{
			Name: "exclude",
			Rel:  "exclude",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"real.go"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestExcludedPbGo(t *testing.T) {
	files := []fileSpec{
		{
			path: "exclude/BUILD",
			content: `
# gazelle:exclude a.proto
`,
		},
		{
			path: "exclude/a.proto",
			content: `syntax = "proto2";
package exclude;`,
		},
		{
			path:    "exclude/a.pb.go",
			content: `package exclude`,
		},
		{
			path: "exclude/b.proto",
			content: `syntax = "proto2";
package exclude;
`,
		},
		{
			path:    "exclude/b.pb.go",
			content: `package exclude`,
		},
	}
	want := []*packages.Package{
		{
			Name: "exclude",
			Rel:  "exclude",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.pb.go"},
				},
			},
			Proto: packages.ProtoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"b.proto"},
				},
				HasPbGo: true,
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestLegacyProtos(t *testing.T) {
	files := []fileSpec{
		{
			path:    "BUILD",
			content: `# gazelle:proto legacy`,
		}, {
			path: "have_pbgo/a.proto",
			content: `syntax = "proto2";
package have_pbgo;`,
		}, {
			path:    "have_pbgo/a.pb.go",
			content: `package have_pbgo`,
		}, {
			path: "no_pbgo/b.proto",
			content: `syntax = "proto2";
package no_pbgo;`,
		}, {
			path:    "no_pbgo/other.go",
			content: `package no_pbgo`,
		}, {
			path: "proto_only/c.proto",
			content: `syntax = "proto2";
package proto_only;`,
		},
	}
	want := []*packages.Package{
		{
			Name: "have_pbgo",
			Rel:  "have_pbgo",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.pb.go"},
				},
			},
			Proto: packages.ProtoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"a.proto"},
				},
				HasPbGo: true,
			},
		}, {
			Name: "no_pbgo",
			Rel:  "no_pbgo",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"other.go"},
				},
			},
			Proto: packages.ProtoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"b.proto"},
				},
				HasPbGo: false,
			},
		},
	}
	checkFiles(t, files, "", want)
}

func TestVendor(t *testing.T) {
	files := []fileSpec{
		{path: "vendor/foo/foo.go", content: "package foo"},
		{path: "x/vendor/bar/bar.go", content: "package bar"},
	}

	for _, tc := range []struct {
		desc string
		mode config.DependencyMode
		want []*packages.Package
	}{
		{
			desc: "external mode",
			mode: config.ExternalMode,
			want: nil,
		},
		{
			desc: "vendored mode",
			mode: config.VendorMode,
			want: []*packages.Package{
				{
					Name: "foo",
					Rel:  "vendor/foo",
					Library: packages.GoTarget{
						Sources: packages.PlatformStrings{
							Generic: []string{"foo.go"},
						},
					},
				},
				{
					Name: "bar",
					Rel:  "x/vendor/bar",
					Library: packages.GoTarget{
						Sources: packages.PlatformStrings{
							Generic: []string{"bar.go"},
						},
					},
				},
			},
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			dir, err := createFiles(files)
			if err != nil {
				os.RemoveAll(dir)
			}

			for _, p := range tc.want {
				p.Dir = filepath.Join(dir, filepath.FromSlash(p.Rel))
			}

			c := &config.Config{
				RepoRoot:            dir,
				GoPrefix:            "",
				ValidBuildFileNames: config.DefaultValidBuildFileNames,
				DepMode:             tc.mode,
			}
			var got []*packages.Package
			packages.Walk(c, dir, func(_ *config.Config, pkg *packages.Package, _ *bf.File) {
				got = append(got, pkg)
			})

			checkPackages(t, got, tc.want)
		})
	}
}

func TestMalformedBuildFile(t *testing.T) {
	files := []fileSpec{
		{path: "BUILD", content: "????"},
		{path: "foo.go", content: "package foo"},
	}
	want := []*packages.Package{}
	checkFiles(t, files, "", want)
}

func TestMultipleBuildFiles(t *testing.T) {
	files := []fileSpec{
		{path: "BUILD"},
		{path: "BUILD.bazel"},
		{path: "foo.go", content: "package foo"},
	}
	want := []*packages.Package{}
	checkFiles(t, files, "", want)
}

func TestMalformedGoFile(t *testing.T) {
	files := []fileSpec{
		{path: "a.go", content: "pakcage foo"},
		{path: "b.go", content: "package foo"},
	}
	want := []*packages.Package{
		{
			Name: "foo",
			Library: packages.GoTarget{
				Sources: packages.PlatformStrings{
					Generic: []string{"b.go", "a.go"},
				},
			},
		},
	}
	checkFiles(t, files, "", want)
}
