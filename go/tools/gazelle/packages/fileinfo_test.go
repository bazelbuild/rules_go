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

package packages

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestOtherFileInfo(t *testing.T) {
	dir := "."
	rel := ""
	for _, tc := range []struct {
		desc, name, source string
		wantTags           []string
	}{
		{
			"empty file",
			"foo.c",
			"",
			nil,
		},
		{
			"tags file",
			"foo.c",
			`// +build foo bar
// +build baz,!ignore

`,
			[]string{"foo bar", "baz,!ignore"},
		},
	} {
		if err := ioutil.WriteFile(tc.name, []byte(tc.source), 0600); err != nil {
			t.Fatal(err)
		}
		defer os.Remove(tc.name)

		got := otherFileInfo(dir, rel, tc.name)

		// Only check that we can extract tags. Everything else is covered
		// by other tests.
		if !reflect.DeepEqual(got.tags, tc.wantTags) {
			t.Errorf("case %q: got %#v; want %#v", got.tags, tc.wantTags)
		}
	}
}

func TestFileNameInfo(t *testing.T) {
	for _, tc := range []struct {
		desc, name string
		want       fileInfo
	}{
		{
			"simple go file",
			"simple.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
			},
		},
		{
			"simple go test",
			"foo_test.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				isTest:   true,
			},
		},
		{
			"test source",
			"test.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				isTest:   false,
			},
		},
		{
			"_test source",
			"_test.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				isTest:   true,
			},
		},
		{
			"source with goos",
			"foo_linux.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "linux",
			},
		},
		{
			"source with goarch",
			"foo_amd64.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goarch:   "amd64",
			},
		},
		{
			"source with goos then goarch",
			"foo_linux_amd64.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "linux",
				goarch:   "amd64",
			},
		},
		{
			"source with goarch then goos",
			"foo_amd64_linux.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "linux",
			},
		},
		{
			"test with goos and goarch",
			"foo_linux_amd64_test.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "linux",
				goarch:   "amd64",
				isTest:   true,
			},
		},
		{
			"test then goos",
			"foo_test_linux.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "linux",
			},
		},
		{
			"goos source",
			"linux.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "",
			},
		},
		{
			"goarch source",
			"amd64.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goarch:   "",
			},
		},
		{
			"goos test",
			"linux_test.go",
			fileInfo{
				ext:      ".go",
				category: goExt,
				goos:     "",
				isTest:   true,
			},
		},
		{
			"c file",
			"foo_test.cxx",
			fileInfo{
				ext:      ".cxx",
				category: cExt,
				isTest:   false,
			},
		},
		{
			"c os test file",
			"foo_linux_test.c",
			fileInfo{
				ext:      ".c",
				category: cExt,
				isTest:   false,
				goos:     "linux",
			},
		},
		{
			"h file",
			"foo_linux.h",
			fileInfo{
				ext:      ".h",
				category: hExt,
				goos:     "linux",
			},
		},
		{
			"go asm file",
			"foo_amd64.s",
			fileInfo{
				ext:      ".s",
				category: sExt,
				goarch:   "amd64",
			},
		},
		{
			"c asm file",
			"foo.S",
			fileInfo{
				ext:      ".S",
				category: csExt,
			},
		},
		{
			"unsupported file",
			"foo.m",
			fileInfo{
				ext:      ".m",
				category: unsupportedExt,
			},
		},
		{
			"ignored test file",
			"foo_test.py",
			fileInfo{
				ext:     ".py",
				isTest:  false,
				isXTest: false,
			},
		},
		{
			"ignored xtest file",
			"foo_xtest.py",
			fileInfo{
				ext:     ".py",
				isTest:  false,
				isXTest: false,
			},
		},
		{
			"ignored file",
			"foo.txt",
			fileInfo{
				ext:      ".txt",
				category: ignoredExt,
			},
		},
	} {
		tc.want.name = tc.name
		tc.want.rel = "dir"
		tc.want.path = filepath.Join("dir", tc.name)

		if got := fileNameInfo("dir", "dir", tc.name); !reflect.DeepEqual(got, tc.want) {
			t.Errorf("case %q: got %#v; want %#v", tc.desc, got, tc.want)
		}
	}
}

func TestJoinOptions(t *testing.T) {
	for _, tc := range []struct {
		opts, want []string
	}{
		{
			opts: nil,
			want: nil,
		}, {
			opts: []string{"a", "b", optSeparator},
			want: []string{"a b"},
		}, {
			opts: []string{`a\`, `b'`, `c"`, `d `, optSeparator},
			want: []string{`a\\ b\' c\" d\ `},
		}, {
			opts: []string{"a", "b", optSeparator, "c", optSeparator},
			want: []string{"a b", "c"},
		},
	} {
		if got := JoinOptions(tc.opts); !reflect.DeepEqual(got, tc.want) {
			t.Errorf("JoinOptions(%#v): got %#v ; want %#v", tc.opts, got, tc.want)
		}
	}
}

func TestIsStandard(t *testing.T) {
	for _, tc := range []struct {
		goPrefix, importpath string
		want                 bool
	}{
		{"", "fmt", true},
		{"", "encoding/json", true},
		{"", "foo/bar", true},
		{"", "foo.com/bar", false},
		{"foo", "fmt", true},
		{"foo", "encoding/json", true},
		{"foo", "foo", true},
		{"foo", "foo/bar", false},
		{"foo", "foo.com/bar", false},
		{"foo.com/bar", "fmt", true},
		{"foo.com/bar", "encoding/json", true},
		{"foo.com/bar", "foo/bar", true},
		{"foo.com/bar", "foo.com/bar", false},
	} {
		if got := isStandard(tc.goPrefix, tc.importpath); got != tc.want {
			t.Errorf("for prefix %q, importpath %q: got %#v; want %#v", tc.goPrefix, tc.importpath, got, tc.want)
		}
	}
}

func TestReadTags(t *testing.T) {
	for _, tc := range []struct {
		desc, source string
		want         []string
	}{
		{
			"empty file",
			"",
			nil,
		},
		{
			"single comment without blank line",
			"// +build foo\npackage main",
			nil,
		},
		{
			"multiple comments without blank link",
			`// +build foo

// +build bar
package main

`,
			[]string{"foo"},
		},
		{
			"single comment",
			"// +build foo\n\n",
			[]string{"foo"},
		},
		{
			"multiple comments",
			`// +build foo
// +build bar

package main`,
			[]string{"foo", "bar"},
		},
		{
			"multiple comments with blank",
			`// +build foo

// +build bar

package main`,
			[]string{"foo", "bar"},
		},
		{
			"comment with space",
			"  //   +build   foo   bar  \n\n",
			[]string{"foo bar"},
		},
		{
			"slash star comment",
			"/* +build foo */\n\n",
			nil,
		},
	} {
		f, err := ioutil.TempFile(".", "TestReadTags")
		if err != nil {
			t.Fatal(err)
		}
		path := f.Name()
		defer os.Remove(path)
		if err = f.Close(); err != nil {
			t.Fatal(err)
		}
		if err = ioutil.WriteFile(path, []byte(tc.source), 0600); err != nil {
			t.Fatal(err)
		}

		if got, err := readTags(path); err != nil {
			t.Fatal(err)
		} else if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("case %q: got %#v; want %#v", tc.desc, got, tc.want)
		}
	}
}

func TestCheckConstraints(t *testing.T) {
	for _, tc := range []struct {
		desc string
		fi   fileInfo
		tags string
		want bool
	}{
		{
			"unconstrained",
			fileInfo{},
			"",
			true,
		},
		{
			"goos satisfied",
			fileInfo{goos: "linux"},
			"linux",
			true,
		},
		{
			"goos unsatisfied",
			fileInfo{goos: "linux"},
			"darwin",
			false,
		},
		{
			"goarch satisfied",
			fileInfo{goarch: "amd64"},
			"amd64",
			true,
		},
		{
			"goarch unsatisfied",
			fileInfo{goarch: "amd64"},
			"arm",
			false,
		},
		{
			"goos goarch satisfied",
			fileInfo{goos: "linux", goarch: "amd64"},
			"linux,amd64",
			true,
		},
		{
			"goos goarch unsatisfied",
			fileInfo{goos: "linux", goarch: "amd64"},
			"darwin,amd64",
			false,
		},
		{
			"tags all satisfied",
			fileInfo{tags: []string{"foo", "bar"}},
			"foo,bar",
			true,
		},
		{
			"tags some unsatisfied",
			fileInfo{tags: []string{"foo", "bar"}},
			"foo",
			false,
		},
		{
			"goos unsatisfied tags satisfied",
			fileInfo{goos: "linux", tags: []string{"foo"}},
			"darwin,foo",
			false,
		},
	} {
		if got := tc.fi.checkConstraints(parseTags(tc.tags)); got != tc.want {
			t.Errorf("case %q: got %#v; want %#v", tc.desc, got, tc.want)
		}
	}
}

func TestCheckTags(t *testing.T) {
	for _, tc := range []struct {
		desc, line, tags string
		want             bool
	}{
		{
			"empty tags",
			"",
			"",
			false,
		},
		{
			"ignored",
			"ignore",
			"",
			false,
		},
		{
			"single satisfied",
			"foo",
			"foo",
			true,
		},
		{
			"single unsatisfied",
			"foo",
			"bar",
			false,
		},
		{
			"NOT satisfied",
			"!foo",
			"",
			true,
		},
		{
			"NOT unsatisfied",
			"!foo",
			"foo",
			false,
		},
		{
			"double negative fails",
			"yes !!yes yes",
			"yes",
			false,
		},
		{
			"AND satisfied",
			"foo,bar",
			"foo,bar",
			true,
		},
		{
			"AND NOT satisfied",
			"foo,!bar",
			"foo",
			true,
		},
		{
			"AND unsatisfied",
			"foo,bar",
			"foo",
			false,
		},
		{
			"AND NOT unsatisfied",
			"foo,!bar",
			"foo,bar",
			false,
		},
		{
			"OR satisfied",
			"foo bar",
			"foo",
			true,
		},
		{
			"OR NOT satisfied",
			"foo !bar",
			"",
			true,
		},
		{
			"OR unsatisfied",
			"foo bar",
			"",
			false,
		},
		{
			"OR NOT unsatisfied",
			"foo !bar",
			"bar",
			false,
		},
		{
			"release tags",
			"go1.7,go1.8,go1.9,go1.91,go2.0",
			"",
			true,
		},
		{
			"release tag negated",
			"!go1.8",
			"",
			true,
		},
	} {
		if got := checkTags(tc.line, parseTags(tc.tags)); got != tc.want {
			t.Errorf("case %q: got %#v; want %#v", tc.desc, got, tc.want)
		}
	}
}

func parseTags(tags string) map[string]bool {
	tagMap := make(map[string]bool)
	for _, t := range strings.Split(tags, ",") {
		tagMap[t] = true
	}
	return tagMap
}
