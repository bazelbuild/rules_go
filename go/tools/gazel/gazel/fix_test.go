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

package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	bzl "github.com/bazelbuild/buildifier/core"
)

func TestFixFile(t *testing.T) {
	tmpdir := os.Getenv("TEST_TMPDIR")
	dir, err := ioutil.TempDir(tmpdir, "")
	if err != nil {
		t.Fatalf("ioutil.TempDir(%q, %q) failed with %v; want success", tmpdir, "", err)
	}
	defer os.RemoveAll(dir)

	stubFile := &bzl.File{
		Path: filepath.Join(dir, "BUILD"),
		Stmt: []bzl.Expr{
			&bzl.CallExpr{
				X: &bzl.LiteralExpr{Token: "foo_rule"},
				List: []bzl.Expr{
					&bzl.BinaryExpr{
						X:  &bzl.LiteralExpr{Token: "name"},
						Op: "=",
						Y:  &bzl.StringExpr{Value: "bar"},
					},
				},
			},
		},
	}

	if err := fixFile(stubFile); err != nil {
		t.Errorf("fixFile(%#v) failed with %v; want success", stubFile, err)
		return
	}

	buf, err := ioutil.ReadFile(stubFile.Path)
	if err != nil {
		t.Errorf("ioutil.ReadFile(%q) failed with %v; want success", stubFile.Path, err)
		return
	}
	if got, want := string(buf), bzl.FormatString(stubFile); got != want {
		t.Errorf("buf = %q; want %q", got, want)
	}
}
