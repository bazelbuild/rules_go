/* Copyright 2017 The Bazel Authors. All rights reserved.

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

// This file contains integration tests for all of Gazelle. It's meant to test
// common usage patterns and check for errors that are difficult to test in
// unit tests.

package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fileSpec struct {
	path, content string
}

func createFiles(files []fileSpec) (string, error) {
	dir, err := ioutil.TempDir(os.Getenv("TEST_TEMPDIR"), "integration_test")
	if err != nil {
		return "", err
	}

	for _, f := range files {
		path := filepath.Join(dir, filepath.FromSlash(f.path))
		if strings.HasSuffix(f.path, "/") {
			if err := os.MkdirAll(path, 0700); err != nil {
				os.RemoveAll(dir)
				return "", err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			os.RemoveAll(dir)
			return "", err
		}
		if err := ioutil.WriteFile(path, []byte(f.content), 0600); err != nil {
			os.RemoveAll(dir)
			return "", err
		}
	}
	return dir, nil
}

func runGazelle(wd string, args []string) error {
	oldWd, err := os.Getwd()
	if err != nil {
		return err
	}
	if err := os.Chdir(wd); err != nil {
		return err
	}
	defer os.Chdir(oldWd)

	c, emit, err := newConfiguration(args)
	if err != nil {
		return err
	}

	run(c, emit)
	return nil
}

func TestNoRepoRootOrWorkspace(t *testing.T) {
	dir, err := createFiles(nil)
	if err != nil {
		t.Fatal(err)
	}
	want := "-repo_root not specified"
	if err := runGazelle(dir, nil); err == nil {
		t.Fatalf("got success; want %q", want)
	} else if !strings.Contains(err.Error(), want) {
		t.Fatalf("got %q; want %q", err, want)
	}
}

func TestNoGoPrefixArgOrRule(t *testing.T) {
	dir, err := createFiles([]fileSpec{
		{path: "WORKSPACE", content: ""},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "-go_prefix not set"
	if err := runGazelle(dir, nil); err == nil {
		t.Fatalf("got success; want %q", want)
	} else if !strings.Contains(err.Error(), want) {
		t.Fatalf("got %q; want %q", err, want)
	}
}

// TODO(jayconrod): more tests
//   multiple directories can be visited
//   error if directory not under -repo_root
//   -go_prefix will create empty file if not already present
//   -go_prefix will change existing file if present
//   -build_file_name to BUILD.bazel ignores BUILD files
//   "BUILD" directory doesn't cause problems
//   -external vendor works
//   run in fix mode in testdata directories to create new files
//   run in diff mode in testdata directories to update existing files (no change)
