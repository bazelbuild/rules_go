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
	"path"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

func TestResolveGoIndex(t *testing.T) {
	c := &config.Config{
		GoPrefix: "example.com/repo",
		DepMode:  config.VendorMode,
	}
	l := NewLabeler(c)

	type fileSpec struct {
		rel, content string
	}
	type testCase struct {
		desc         string
		buildFiles   []fileSpec
		imp, fromRel string
		wantErr      string
		want         Label
	}
	for _, tc := range []testCase{
		{
			desc: "no_match",
			imp:  "example.com/foo",
			// fall back to external resolver
			want: Label{Pkg: "vendor/example.com/foo", Name: config.DefaultLibName},
		}, {
			desc: "simple",
			buildFiles: []fileSpec{{
				rel: "foo",
				content: `
go_library(
    name = "go_default_library",
    importpath = "example.com/foo",
)
`}},
			imp:  "example.com/foo",
			want: Label{Pkg: "foo", Name: "go_default_library"},
		}, {
			desc: "test_and_library_not_indexed",
			buildFiles: []fileSpec{{
				rel: "foo",
				content: `
go_test(
    name = "go_default_test",
    importpath = "example.com/foo",
)

go_binary(
    name = "cmd",
    importpath = "example.com/foo",
)
`,
			}},
			imp: "example.com/foo",
			// fall back to external resolver
			want: Label{Pkg: "vendor/example.com/foo", Name: config.DefaultLibName},
		}, {
			desc: "multiple_rules_ambiguous",
			buildFiles: []fileSpec{{
				rel: "foo",
				content: `
go_library(
    name = "a",
    importpath = "example.com/foo",
)

go_library(
    name = "b",
    importpath = "example.com/foo",
)
`,
			}},
			imp:     "example.com/foo",
			wantErr: "multiple rules",
		}, {
			desc: "vendor_not_visible",
			buildFiles: []fileSpec{
				{
					rel: "",
					content: `
go_library(
    name = "root",
    importpath = "example.com/foo",
)
`,
				}, {
					rel: "a/vendor/foo",
					content: `
go_library(
    name = "vendored",
    importpath = "example.com/foo",
)
`,
				},
			},
			imp:     "example.com/foo",
			fromRel: "b",
			want:    Label{Name: "root"},
		}, {
			desc: "vendor_supercedes_nonvendor",
			buildFiles: []fileSpec{
				{
					rel: "",
					content: `
go_library(
    name = "root",
    importpath = "example.com/foo",
)
`,
				}, {
					rel: "vendor/foo",
					content: `
go_library(
    name = "vendored",
    importpath = "example.com/foo",
)
`,
				},
			},
			imp:  "example.com/foo",
			want: Label{Pkg: "vendor/foo", Name: "vendored"},
		}, {
			desc: "deep_vendor_shallow_vendor",
			buildFiles: []fileSpec{
				{
					rel: "shallow/vendor",
					content: `
go_library(
    name = "shallow",
    importpath = "example.com/foo",
)
`,
				}, {
					rel: "shallow/deep/vendor",
					content: `
go_library(
    name = "deep",
    importpath = "example.com/foo",
)
`,
				},
			},
			imp:     "example.com/foo",
			fromRel: "shallow/deep",
			want:    Label{Pkg: "shallow/deep/vendor", Name: "deep"},
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			ix := NewRuleIndex()
			for _, fs := range tc.buildFiles {
				f, err := bf.Parse(path.Join(fs.rel, "BUILD.bazel"), []byte(fs.content))
				if err != nil {
					t.Fatal(err)
				}
				ix.AddRulesFromFile(c, f)
			}

			ix.Finish()

			r := NewResolver(c, l, ix)
			got, err := r.resolveGo(tc.imp, tc.fromRel)
			if err != nil {
				if tc.wantErr == "" {
					t.Fatal(err)
				}
				if !strings.Contains(err.Error(), tc.wantErr) {
					t.Fatalf("got %q ; want %q", err.Error(), tc.wantErr)
				}
				return
			}
			if err == nil && tc.wantErr != "" {
				t.Fatalf("got success ; want error %q", tc.wantErr)
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("got %v ; want %v", got, tc.want)
			}
		})
	}
}

func TestResolveProtoIndex(t *testing.T) {
	c := &config.Config{
		GoPrefix: "example.com/repo",
		DepMode:  config.VendorMode,
	}
	l := NewLabeler(c)

	buildContent := []byte(`
proto_library(
    name = "foo_proto",
    srcs = ["bar.proto"],
)

go_proto_library(
    name = "foo_go_proto",
    importpath = "example.com/foo",
    proto = ":foo_proto",
)

go_library(
    name = "embed",
    embed = [":foo_go_proto"],
    importpath = "example.com/foo",
)
`)
	f, err := bf.Parse(filepath.Join("sub", "BUILD.bazel"), buildContent)
	if err != nil {
		t.Fatal(err)
	}

	ix := NewRuleIndex()
	ix.AddRulesFromFile(c, f)
	ix.Finish()
	r := NewResolver(c, l, ix)

	wantProto := Label{Pkg: "sub", Name: "foo_proto"}
	if got, err := r.resolveProto("sub/bar.proto", "baz"); err != nil {
		t.Error(err)
	} else if !reflect.DeepEqual(got, wantProto) {
		t.Errorf("resolveProto: got %s ; want %s", got, wantProto)
	}

	wantGoProto := Label{Pkg: "sub", Name: "embed"}
	if got, err := r.resolveGoProto("sub/bar.proto", "baz"); err != nil {
		t.Error(err)
	} else if !reflect.DeepEqual(got, wantGoProto) {
		t.Errorf("resolveGoProto: got %s ; want %s", got, wantGoProto)
	}
}

func TestIndexGenRuleReplacesOldRule(t *testing.T) {
	c := &config.Config{
		GoPrefix: "example.com/repo",
		DepMode:  config.VendorMode,
	}
	ix := NewRuleIndex()

	buildContent := []byte(`
go_library(
    name = "go_default_library",
    importpath = "example.com/old",
)
`)
	oldFile, err := bf.Parse("BUILD.bazel", buildContent)
	if err != nil {
		t.Fatal(err)
	}
	ix.AddRulesFromFile(c, oldFile)

	genContent := []byte(`
go_library(
    name = "go_default_library",
    importpath = "example.com/new",
)
`)
	genFile, err := bf.Parse("gen", genContent)
	if err != nil {
		t.Fatal(err)
	}
	ix.AddGeneratedRules(c, "", genFile.Stmt)

	ix.Finish()

	got, err := ix.findLabelByImport(importSpec{config.GoLang, "example.com/old"}, config.GoLang, "")
	if err == nil {
		t.Errorf("when importing example.com/old, got %s ; want error", got)
	}

	got, err = ix.findLabelByImport(importSpec{config.GoLang, "example.com/new"}, config.GoLang, "")
	want := Label{Name: "go_default_library"}
	if err != nil {
		t.Errorf("when importing example.com/new, got error %v ; want %s", err, want)
	} else if !reflect.DeepEqual(got, want) {
		t.Errorf("when importing example.com/new, got %s ; want %s", got, want)
	}
}

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
		ix := NewRuleIndex()
		r := NewResolver(c, l, ix)
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
	ix := NewRuleIndex()
	r := NewResolver(c, l, ix)

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
	ix := NewRuleIndex()
	r := NewResolver(c, l, ix)

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
			ix := NewRuleIndex()
			r := NewResolver(c, l, ix)

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
