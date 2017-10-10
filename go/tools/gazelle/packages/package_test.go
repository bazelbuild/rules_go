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
	"fmt"
	"path"
	"reflect"
	"testing"
)

func TestImportPath(t *testing.T) {
	prefix := "example.com/repo"
	for _, tc := range []struct {
		name, rel, prefix, want string
	}{
		{
			name: "simple_vendor",
			rel:  "vendor/foo/bar",
			want: "foo/bar",
		}, {
			name: "empty_vendor",
			rel:  "vendor",
			want: "",
		}, {
			name: "multi_vendor",
			rel:  "vendor/foo/vendor/bar",
			want: "bar",
		}, {
			name: "prefix",
			rel:  "foo/bar",
			want: "example.com/repo/foo/bar",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			pkg := Package{
				Name: path.Base(tc.rel),
				Rel:  tc.rel,
				Library: GoTarget{
					Sources: PlatformStrings{
						Generic: []string{"a.go"},
					},
				},
			}
			if got := pkg.ImportPath(prefix); got != tc.want {
				t.Errorf("%s: got %q ; want %q", tc.name, got, tc.want)
			}
		})
	}
}

func TestImportPathNoLib(t *testing.T) {
	pkg := Package{
		Name: "bar",
		Rel:  "foo/bar",
	}
	if got, want := pkg.ImportPath("example.com/repo"), "example.com/repo/foo/bar"; got != want {
		t.Errorf(`got %q; want %q`, got, want)
	}
}

func TestImportPathCmd(t *testing.T) {
	pkg := Package{
		Name: "main",
		Rel:  "foo/bar",
		Library: GoTarget{
			Sources: PlatformStrings{
				Generic: []string{"main.go"},
			},
		},
	}
	if got, want := pkg.ImportPath("example.com/repo"), "example.com/repo/foo/bar"; got != want {
		t.Errorf(`got %q; want %q`, got, want)
	}
}

func TestCleanPlatformStrings(t *testing.T) {
	for _, tc := range []struct {
		desc     string
		ps, want PlatformStrings
	}{
		{
			desc: "empty",
		},
		{
			desc: "sort and uniq",
			ps: PlatformStrings{
				Generic: []string{"b", "a", "b"},
				Platform: map[string][]string{
					"linux": []string{"d", "c", "d"},
				},
			},
			want: PlatformStrings{
				Generic: []string{"a", "b"},
				Platform: map[string][]string{
					"linux": []string{"c", "d"},
				},
			},
		},
		{
			desc: "remove generic string from platform",
			ps: PlatformStrings{
				Generic: []string{"a"},
				Platform: map[string][]string{
					"linux": []string{"a"},
				},
			},
			want: PlatformStrings{
				Generic: []string{"a"},
			},
		},
	} {
		tc.ps.Clean()
		if !reflect.DeepEqual(tc.ps, tc.want) {
			t.Errorf("%s: got %#v; want %#v", tc.desc, tc.ps, tc.want)
		}
	}
}

func TestMapPlatformStrings(t *testing.T) {
	f := func(s string) (string, error) {
		if len(s) > 0 && s[0] == 'e' {
			return "", fmt.Errorf("invalid string: %s", s)
		}
		return s + "x", nil
	}
	ps := PlatformStrings{
		Generic: []string{"a", "e1"},
		Platform: map[string][]string{
			"linux": []string{"b", "e2"},
		},
	}
	got, gotErrors := ps.Map(f)

	want := PlatformStrings{
		Generic: []string{"ax"},
		Platform: map[string][]string{
			"linux": []string{"bx"},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %#v; want %#v", got, want)
	}

	wantErrors := []error{
		fmt.Errorf("invalid string: e1"),
		fmt.Errorf("invalid string: e2"),
	}
	if !reflect.DeepEqual(gotErrors, wantErrors) {
		t.Errorf("got errors %#v; want errors %#v", gotErrors, wantErrors)
	}
}
