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
		p.Dir = filepath.Join(dir, filepath.FromSlash(p.Dir))
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
	var pkgs []*packages.Package
	packages.Walk(nil, nil, repoRoot, goPrefix, dir, func(pkg *packages.Package) {
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
		{path: "b/"},
	}
	want := []*packages.Package{}
	checkFiles(t, files, "", want)
}

func TestWalkSimple(t *testing.T) {
	files := []fileSpec{{path: "lib.go", content: "package lib"}}
	want := []*packages.Package{
		{
			Name: "lib",
			Library: packages.Target{
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
			Dir:  "a",
			Library: packages.Target{
				Sources: packages.PlatformStrings{
					Generic: []string{"foo.go"},
				},
			},
		},
		{
			Name: "c",
			Dir:  "b/c",
			Library: packages.Target{
				Sources: packages.PlatformStrings{
					Generic: []string{"bar.go"},
				},
			},
		},
		{
			Name: "main",
			Dir:  "b/d",
			Library: packages.Target{
				Sources: packages.PlatformStrings{
					Generic: []string{"baz.go"},
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
			Dir:  "a",
			Library: packages.Target{
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

func TestRootWithPrefix(t *testing.T) {
	files := []fileSpec{
		{path: "a.go", content: "package a"},
		{path: "b.go", content: "package b"},
	}
	want := []*packages.Package{
		{
			Name: "a",
			Library: packages.Target{
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
