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

package resolve

import (
	"reflect"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

func TestLabelString(t *testing.T) {
	for _, spec := range []struct {
		l    Label
		want string
	}{
		{
			l:    Label{Name: "foo"},
			want: "//:foo",
		},
		{
			l:    Label{Pkg: "foo/bar", Name: "baz"},
			want: "//foo/bar:baz",
		},
		{
			l:    Label{Pkg: "foo/bar", Name: "bar"},
			want: "//foo/bar",
		},
		{
			l:    Label{Repo: "com_example_repo", Pkg: "foo/bar", Name: "baz"},
			want: "@com_example_repo//foo/bar:baz",
		},
		{
			l:    Label{Repo: "com_example_repo", Pkg: "foo/bar", Name: "bar"},
			want: "@com_example_repo//foo/bar",
		},
		{
			l:    Label{Relative: true, Name: "foo"},
			want: ":foo",
		},
	} {
		if got, want := spec.l.String(), spec.want; got != want {
			t.Errorf("%#v.String() = %q; want %q", spec.l, got, want)
		}
	}
}

func TestResolveGoLocal(t *testing.T) {
	for _, spec := range []struct {
		mode       config.StructureMode
		importpath string
		pkgRel     string
		want       Label
	}{
		{
			importpath: "example.com/repo",
			want:       Label{Name: config.DefaultLibName},
		}, {
			importpath: "example.com/repo/lib",
			want:       Label{Pkg: "lib", Name: config.DefaultLibName},
		}, {
			importpath: "example.com/repo/another",
			want:       Label{Pkg: "another", Name: config.DefaultLibName},
		}, {
			importpath: "example.com/repo",
			want:       Label{Name: config.DefaultLibName},
		}, {
			importpath: "example.com/repo/lib/sub",
			want:       Label{Pkg: "lib/sub", Name: config.DefaultLibName},
		}, {
			importpath: "example.com/repo/another",
			want:       Label{Pkg: "another", Name: config.DefaultLibName},
		}, {
			importpath: "../y",
			pkgRel:     "x",
			want:       Label{Pkg: "y", Name: config.DefaultLibName},
		},
	} {
		c := &config.Config{GoPrefix: "example.com/repo", StructureMode: spec.mode}
		l := NewLabeler(c)
		r := NewResolver(c, l)
		label, err := r.ResolveGo(spec.importpath, spec.pkgRel)
		if err != nil {
			t.Errorf("r.ResolveGo(%q) failed with %v; want success", spec.importpath, err)
			continue
		}
		if got, want := label, spec.want; !reflect.DeepEqual(got, want) {
			t.Errorf("r.ResolveGo(%q) = %s; want %s", spec.importpath, got, want)
		}
	}
}

func TestResolveGoLocalError(t *testing.T) {
	c := &config.Config{GoPrefix: "example.com/repo"}
	l := NewLabeler(c)
	r := NewResolver(c, l)

	for _, importpath := range []string{
		"example.com/another",
		"example.com/another/sub",
		"example.com/repo_suffix",
	} {
		if l, err := r.ResolveGo(importpath, ""); err == nil {
			t.Errorf("r.ResolveGo(%q) = %s; want error", importpath, l)
		}
	}

	if l, err := r.ResolveGo("..", ""); err == nil {
		t.Errorf("r.ResolveGo(%q) = %s; want error", "..", l)
	}
}

func TestResolveProto(t *testing.T) {
	prefix := "example.com/repo"
	for _, tc := range []struct {
		desc, imp              string
		mode                   config.StructureMode
		wantProto, wantGoProto Label
	}{
		{
			desc:        "root",
			imp:         "foo.proto",
			wantProto:   Label{Name: "repo_proto"},
			wantGoProto: Label{Name: config.DefaultLibName},
		}, {
			desc:        "sub",
			imp:         "foo/bar/bar.proto",
			wantProto:   Label{Pkg: "foo/bar", Name: "bar_proto"},
			wantGoProto: Label{Pkg: "foo/bar", Name: config.DefaultLibName},
		}, {
			desc:        "flat sub",
			mode:        config.FlatMode,
			imp:         "foo/bar/bar.proto",
			wantProto:   Label{Name: "foo/bar/bar_proto"},
			wantGoProto: Label{Name: "foo/bar"},
		}, {
			desc:        "well known",
			imp:         "google/protobuf/any.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "any_proto"},
			wantGoProto: Label{Repo: "com_github_golang_protobuf", Pkg: "ptypes/any", Name: config.DefaultLibName},
		}, {
			desc:        "well known flat",
			mode:        config.FlatMode,
			imp:         "google/protobuf/any.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "any_proto"},
			wantGoProto: Label{Repo: "com_github_golang_protobuf", Name: "ptypes/any"},
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			c := &config.Config{GoPrefix: prefix, StructureMode: tc.mode}
			l := NewLabeler(c)
			r := NewResolver(c, l)

			got, err := r.ResolveProto(tc.imp)
			if err != nil {
				t.Errorf("ResolveProto: got error %v ; want success", err)
			}
			if !reflect.DeepEqual(got, tc.wantProto) {
				t.Errorf("ResolveProto: got %s ; want %s", got, tc.wantProto)
			}

			got, err = r.ResolveGoProto(tc.imp)
			if err != nil {
				t.Errorf("ResolveGoProto: go error %v ; want success", err)
			}
			if !reflect.DeepEqual(got, tc.wantGoProto) {
				t.Errorf("ResolveGoProto: got %s ; want %s", got, tc.wantGoProto)
			}
		})
	}
}
