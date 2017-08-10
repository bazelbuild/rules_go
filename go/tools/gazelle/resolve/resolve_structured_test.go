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

func TestStructuredResolver(t *testing.T) {
	for _, spec := range []struct {
		mode       config.StructureMode
		importpath string
		want       Label
	}{
		{
			importpath: "example.com/repo",
			want:       Label{Name: config.DefaultLibName},
		},
		{
			importpath: "example.com/repo/lib",
			want:       Label{Pkg: "lib", Name: config.DefaultLibName},
		},
		{
			importpath: "example.com/repo/another",
			want:       Label{Pkg: "another", Name: config.DefaultLibName},
		},

		{
			importpath: "example.com/repo",
			want:       Label{Name: config.DefaultLibName},
		},
		{
			importpath: "example.com/repo/lib/sub",
			want:       Label{Pkg: "lib/sub", Name: config.DefaultLibName},
		},
		{
			importpath: "example.com/repo/another",
			want:       Label{Pkg: "another", Name: config.DefaultLibName},
		},
	} {
		l := NewLabeler(&config.Config{StructureMode: spec.mode})
		r := structuredResolver{l: l, goPrefix: "example.com/repo"}
		label, err := r.Resolve(spec.importpath)
		if err != nil {
			t.Errorf("r.Resolve(%q) failed with %v; want success", spec.importpath, err)
			continue
		}
		if got, want := label, spec.want; !reflect.DeepEqual(got, want) {
			t.Errorf("r.Resolve(%q) = %s; want %s", spec.importpath, got, want)
		}
	}
}

func TestStructuredResolverError(t *testing.T) {
	r := structuredResolver{goPrefix: "example.com/repo"}

	for _, importpath := range []string{
		"example.com/another",
		"example.com/another/sub",
		"example.com/repo_suffix",
	} {
		if l, err := r.Resolve(importpath); err == nil {
			t.Errorf("r.Resolve(%q) = %s; want error", importpath, l)
		}
	}
}
