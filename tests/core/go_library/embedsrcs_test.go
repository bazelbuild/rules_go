// Copyright 2021 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package embedsrcs

import (
	"bytes"
	"embed"
	"io/fs"
	"strings"
	"testing"
)

//go:embed embedsrcs_test.go
var self embed.FS

//go:embed embedsrcs_static/file embedsrcs_static/dir embedsrcs_static/glob/*
var static embed.FS

//go:embed embedsrcs_dynamic/file embedsrcs_dynamic/dir embedsrcs_dynamic/glob/*
var dynamic embed.FS

//go:embed embedsrcs_transitioned
var transitioned embed.FS

//go:embed *
var star embed.FS

//go:embed all:embedsrcs_static/contains_hidden
var all embed.FS

//go:embed embedsrcs_static/contains_hidden
var allButHidden embed.FS

func TestFiles(t *testing.T) {
	for _, test := range []struct {
		desc string
		fsys fs.FS
		want []string
	}{
		{
			desc: "self",
			fsys: self,
			want: []string{
				".",
				"embedsrcs_test.go",
			},
		},
		{
			desc: "gen",
			fsys: gen,
			want: []string{
				".",
				"embedsrcs_test.go",
			},
		},
		{
			desc: "static",
			fsys: static,
			want: []string{
				".",
				"embedsrcs_static",
				"embedsrcs_static/dir",
				"embedsrcs_static/dir/f",
				"embedsrcs_static/file",
				"embedsrcs_static/glob",
				"embedsrcs_static/glob/_hidden",
				"embedsrcs_static/glob/f",
			},
		},
		{
			desc: "dynamic",
			fsys: dynamic,
			want: []string{
				".",
				"embedsrcs_dynamic",
				"embedsrcs_dynamic/dir",
				"embedsrcs_dynamic/dir/f",
				"embedsrcs_dynamic/file",
				"embedsrcs_dynamic/glob",
				"embedsrcs_dynamic/glob/_hidden",
				"embedsrcs_dynamic/glob/f",
			},
		},
		{
			desc: "transitioned",
			fsys: transitioned,
			want: []string{
				".",
				"embedsrcs_transitioned",
			},
		},
		{
			desc: "star",
			fsys: star,
			want: []string{
				".",
				"embedsrcs_dynamic",
				"embedsrcs_dynamic/dir",
				"embedsrcs_dynamic/dir/f",
				"embedsrcs_dynamic/empty",
				"embedsrcs_dynamic/file",
				"embedsrcs_dynamic/glob",
				"embedsrcs_dynamic/glob/f",
				"embedsrcs_dynamic/no",
				"embedsrcs_static",
				"embedsrcs_static/contains_hidden",
				"embedsrcs_static/contains_hidden/visible",
				"embedsrcs_static/contains_hidden/visible/visible_file",
				"embedsrcs_static/dir",
				"embedsrcs_static/dir/f",
				"embedsrcs_static/file",
				"embedsrcs_static/glob",
				"embedsrcs_static/glob/f",
				"embedsrcs_static/no",
				"embedsrcs_test.go",
				"embedsrcs_transitioned",
			},
		},
		{
			desc: "all",
			fsys: all,
			want: []string{
				".",
				"embedsrcs_static",
				"embedsrcs_static/contains_hidden",
				"embedsrcs_static/contains_hidden/.hidden",
				"embedsrcs_static/contains_hidden/.hidden_dir",
				"embedsrcs_static/contains_hidden/.hidden_dir/.env",
				"embedsrcs_static/contains_hidden/.hidden_dir/visible_file",
				"embedsrcs_static/contains_hidden/_hidden_dir",
				"embedsrcs_static/contains_hidden/_hidden_dir/.bashrc",
				"embedsrcs_static/contains_hidden/_hidden_dir/_hidden_file",
				"embedsrcs_static/contains_hidden/_hidden_dir/visible_file",
				"embedsrcs_static/contains_hidden/visible",
				"embedsrcs_static/contains_hidden/visible/visible_file",
			},
		},
		{
			desc: "allButHidden",
			fsys: allButHidden,
			want: []string{
				".",
				"embedsrcs_static",
				"embedsrcs_static/contains_hidden",
				"embedsrcs_static/contains_hidden/visible",
				"embedsrcs_static/contains_hidden/visible/visible_file",
			},
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			got, err := listFiles(test.fsys)
			if err != nil {
				t.Fatal(err)
			}
			gotStr := strings.Join(got, "\n")
			wantStr := strings.Join(test.want, "\n")
			if gotStr != wantStr {
				t.Errorf("got:\n%s\nwant:\n%s", gotStr, wantStr)
			}
		})
	}
}

func listFiles(fsys fs.FS) ([]string, error) {
	var files []string
	err := fs.WalkDir(fsys, ".", func(path string, _ fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		files = append(files, path)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return files, nil
}

func TestContent(t *testing.T) {
	data, err := fs.ReadFile(self, "embedsrcs_test.go")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(data, []byte("package embedsrcs")) {
		t.Error("embedded content did not contain package declaration")
	}
}
