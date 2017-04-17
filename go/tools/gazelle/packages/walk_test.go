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
	"go/build"
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

func checkFiles(t *testing.T, files []fileSpec, want []*build.Package) {
	dir, err := createFiles(files)
	if err != nil {
		t.Fatalf("createFiles() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	got, err := walkPackages(dir)
	if err != nil {
		t.Errorf("walkPackages(%q) failed with %v; want success", dir, err)
	}
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

func walkPackages(root string) ([]*build.Package, error) {
	var pkgs []*build.Package
	err := packages.Walk(build.Default, root, func(pkg *build.Package) error {
		pkgs = append(pkgs, pkg)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return pkgs, nil
}

func checkPackages(t *testing.T, got []*build.Package, want []*build.Package) {
	if len(got) != len(want) {
		t.Fatalf("got %d packages; want %d", len(got), len(want))
	}
	for i := 0; i < len(got); i++ {
		checkPackage(t, got[i], want[i])
	}
}

func checkPackage(t *testing.T, got, want *build.Package) {
	if !reflect.DeepEqual(got.Name, want.Name) {
		t.Errorf("got package name %q; want %q", got.Name, want.Name)
	}
	if !reflect.DeepEqual(got.GoFiles, want.GoFiles) {
		t.Errorf("in package %q, got GoFiles %v; want %v", got.Name, got.GoFiles, want.GoFiles)
	}
	if !reflect.DeepEqual(got.CgoFiles, want.CgoFiles) {
		t.Errorf("in package %q, got CgoFiles %v; want %v", got.Name, got.CgoFiles, want.CgoFiles)
	}
	if !reflect.DeepEqual(got.CFiles, want.CFiles) {
		t.Errorf("in package %q, got CFiles %v; want %v", got.Name, got.CFiles, want.CFiles)
	}
	if !reflect.DeepEqual(got.TestGoFiles, want.TestGoFiles) {
		t.Errorf("in package %q, got TestGoFiles %v; want %v", got.Name, got.TestGoFiles, want.TestGoFiles)
	}
	if !reflect.DeepEqual(got.XTestGoFiles, want.XTestGoFiles) {
		t.Errorf("in package %q, got XTestGoFiles %v; want %v", got.Name, got.XTestGoFiles, want.XTestGoFiles)
	}
}

func TestWalkEmpty(t *testing.T) {
	files := []fileSpec{
		{path: "a/foo.c"},
		{path: "b/"},
	}
	want := []*build.Package{}
	checkFiles(t, files, want)
}

func TestWalkSimple(t *testing.T) {
	files := []fileSpec{{path: "lib.go", content: "package lib"}}
	want := []*build.Package{
		{
			Name:    "lib",
			GoFiles: []string{"lib.go"},
		},
	}
	checkFiles(t, files, want)
}

func TestWalkNested(t *testing.T) {
	files := []fileSpec{
		{path: "a/foo.go", content: "package a"},
		{path: "b/c/bar.go", content: "package c"},
		{path: "b/d/baz.go", content: "package main"},
	}
	want := []*build.Package{
		{
			Name:    "a",
			GoFiles: []string{"foo.go"},
		},
		{
			Name:    "c",
			GoFiles: []string{"bar.go"},
		},
		{
			Name:    "main",
			GoFiles: []string{"baz.go"},
		},
	}
	checkFiles(t, files, want)
}

func TestMultiplePackagesWithDefault(t *testing.T) {
	files := []fileSpec{
		{path: "a/a.go", content: "package a"},
		{path: "a/b.go", content: "package b"},
	}
	want := []*build.Package{
		{
			Name:    "a",
			GoFiles: []string{"a.go"},
		},
	}
	checkFiles(t, files, want)
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

	_, err = walkPackages(dir)
	if _, ok := err.(*build.MultiplePackageError); !ok {
		t.Errorf("got %v; want MultiplePackageError", err)
	}
}
