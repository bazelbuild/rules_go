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

package rules

import (
	"testing"
)

func TestLabelString(t *testing.T) {
	for _, spec := range []struct {
		l    label
		want string
	}{
		{
			l:    label{name: "foo"},
			want: "//:foo",
		},
		{
			l:    label{pkg: "foo/bar", name: "baz"},
			want: "//foo/bar:baz",
		},
		{
			l:    label{pkg: "foo/bar", name: "bar"},
			want: "//foo/bar",
		},
		{
			l:    label{repo: "com_example_repo", pkg: "foo/bar", name: "baz"},
			want: "@com_example_repo//foo/bar:baz",
		},
		{
			l:    label{repo: "com_example_repo", pkg: "foo/bar", name: "bar"},
			want: "@com_example_repo//foo/bar",
		},
		{
			l:    label{relative: true, name: "foo"},
			want: ":foo",
		},
	} {
		if got, want := spec.l.String(), spec.want; got != want {
			t.Errorf("%#v.String() = %q; want %q", spec.l, got, want)
		}
	}
}
