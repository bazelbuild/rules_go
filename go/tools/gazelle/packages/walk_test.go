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
	"sort"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
)

func tempDir() (string, error) {
	return ioutil.TempDir(os.Getenv("TEST_TMPDIR"), "walk_test")
}

func TestWalkSimple(t *testing.T) {
	dir, err := tempDir()
	if err != nil {
		t.Fatalf("tempDir() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	fname := filepath.Join(dir, "lib.go")
	if err := ioutil.WriteFile(fname, []byte("package lib"), 0600); err != nil {
		t.Fatalf(`ioutil.WriteFile(%q, "package lib", 0600) failed with %v; want success`, fname, err)
	}

	var n int
	err = packages.Walk(build.Default, dir, func(pkg *build.Package) error {
		if got, want := pkg.Name, "lib"; got != want {
			t.Errorf("pkg.Name = %q; want %q", got, want)
		}
		n++
		return nil
	})
	if err != nil {
		t.Errorf("packages.Walk(build.Default, %q, func) failed with %v; want success", dir, err)
	}
	if got, want := n, 1; got != want {
		t.Errorf("n = %d; want %d", got, want)
	}
}

func TestWalkNested(t *testing.T) {
	dir, err := tempDir()
	if err != nil {
		t.Fatalf("tempDir() failed with %v; want success", err)
	}
	defer os.RemoveAll(dir)

	for _, p := range []struct {
		path, content string
	}{
		{path: "a/foo.go", content: "package a"},
		{path: "b/c/bar.go", content: "package c"},
		{path: "b/d/baz.go", content: "package main"},
	} {
		path := filepath.Join(dir, p.path)
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			t.Fatalf("os.MkdirAll(%q, 0700) failed with %v; want success", filepath.Dir(path), err)
		}
		if err := ioutil.WriteFile(path, []byte(p.content), 0600); err != nil {
			t.Fatalf("ioutil.WriteFile(%q, %q, 0600) failed with %v; want success", path, p.content, err)
		}
	}

	var dirs, pkgs []string
	err = packages.Walk(build.Default, dir, func(pkg *build.Package) error {
		rel, err := filepath.Rel(dir, pkg.Dir)
		if err != nil {
			t.Errorf("filepath.Rel(%q, %q) failed with %v; want success", dir, pkg.Dir, err)
			return err
		}
		dirs = append(dirs, filepath.ToSlash(rel))
		pkgs = append(pkgs, pkg.Name)
		return nil
	})
	if err != nil {
		t.Errorf("packages.Walk(build.Default, %q, func) failed with %v; want success", dir, err)
	}

	sort.Strings(dirs)
	if got, want := dirs, []string{"a", "b/c", "b/d"}; !reflect.DeepEqual(got, want) {
		t.Errorf("pkgs = %q; want %q", got, want)
	}
	sort.Strings(pkgs)
	if got, want := pkgs, []string{"a", "c", "main"}; !reflect.DeepEqual(got, want) {
		t.Errorf("pkgs = %q; want %q", got, want)
	}
}
