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

func TestResolveGoLocal(t *testing.T) {
	for _, spec := range []struct {
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
		c := &config.Config{GoPrefix: "example.com/repo"}
		l := NewLabeler(c)
		r := NewResolver(c, l)
		label, err := r.resolveGo(spec.importpath, spec.pkgRel)
		if err != nil {
			t.Errorf("r.resolveGo(%q) failed with %v; want success", spec.importpath, err)
			continue
		}
		if got, want := label, spec.want; !reflect.DeepEqual(got, want) {
			t.Errorf("r.resolveGo(%q) = %s; want %s", spec.importpath, got, want)
		}
	}
}

func TestResolveGoLocalError(t *testing.T) {
	c := &config.Config{GoPrefix: "example.com/repo"}
	l := NewLabeler(c)
	r := NewResolver(c, l)

	for _, importpath := range []string{
		"fmt",
		"example.com/another",
		"example.com/another/sub",
		"example.com/repo_suffix",
	} {
		if l, err := r.resolveGo(importpath, ""); err == nil {
			t.Errorf("r.resolveGo(%q) = %s; want error", importpath, l)
		}
	}

	if l, err := r.resolveGo("..", ""); err == nil {
		t.Errorf("r.resolveGo(%q) = %s; want error", "..", l)
	}
}

func TestResolveGoEmptyPrefix(t *testing.T) {
	c := &config.Config{}
	l := NewLabeler(c)
	r := NewResolver(c, l)

	imp := "foo"
	want := Label{Pkg: "foo", Name: config.DefaultLibName}
	if got, err := r.resolveGo(imp, ""); err != nil {
		t.Errorf("r.resolveGo(%q) failed with %v; want success", imp, err)
	} else if !reflect.DeepEqual(got, want) {
		t.Errorf("r.resolveGo(%q) = %s; want %s", imp, got, want)
	}

	imp = "fmt"
	if _, err := r.resolveGo(imp, ""); err == nil {
		t.Errorf("r.resolveGo(%q) succeeded; want failure")
	}
}

func TestResolveProto(t *testing.T) {
	prefix := "example.com/repo"
	for _, tc := range []struct {
		desc, imp, pkgRel      string
		depMode                config.DependencyMode
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
			desc:        "vendor",
			depMode:     config.VendorMode,
			imp:         "foo/bar/bar.proto",
			pkgRel:      "vendor",
			wantProto:   Label{Pkg: "foo/bar", Name: "bar_proto"},
			wantGoProto: Label{Pkg: "vendor/foo/bar", Name: config.DefaultLibName},
		}, {
			desc:        "well known",
			imp:         "google/protobuf/any.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "any_proto"},
			wantGoProto: Label{Repo: "com_github_golang_protobuf", Pkg: "ptypes/any", Name: config.DefaultLibName},
		}, {
			desc:        "well known vendor",
			depMode:     config.VendorMode,
			imp:         "google/protobuf/any.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "any_proto"},
			wantGoProto: Label{Pkg: "vendor/github.com/golang/protobuf/ptypes/any", Name: config.DefaultLibName},
		}, {
			desc:        "descriptor",
			imp:         "google/protobuf/descriptor.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "descriptor_proto"},
			wantGoProto: Label{Repo: "com_github_golang_protobuf", Pkg: "protoc-gen-go/descriptor", Name: config.DefaultLibName},
		}, {
			desc:        "descriptor vendor",
			depMode:     config.VendorMode,
			imp:         "google/protobuf/descriptor.proto",
			wantProto:   Label{Repo: "com_google_protobuf", Name: "descriptor_proto"},
			wantGoProto: Label{Pkg: "vendor/github.com/golang/protobuf/protoc-gen-go/descriptor", Name: config.DefaultLibName},
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			c := &config.Config{
				GoPrefix: prefix,
				DepMode:  tc.depMode,
			}
			l := NewLabeler(c)
			r := NewResolver(c, l)

			got, err := r.resolveProto(tc.imp, tc.pkgRel)
			if err != nil {
				t.Errorf("resolveProto: got error %v ; want success", err)
			}
			if !reflect.DeepEqual(got, tc.wantProto) {
				t.Errorf("resolveProto: got %s ; want %s", got, tc.wantProto)
			}

			got, err = r.resolveGoProto(tc.imp, tc.pkgRel)
			if err != nil {
				t.Errorf("resolveGoProto: go error %v ; want success", err)
			}
			if !reflect.DeepEqual(got, tc.wantGoProto) {
				t.Errorf("resolveGoProto: got %s ; want %s", got, tc.wantGoProto)
			}
		})
	}
}
