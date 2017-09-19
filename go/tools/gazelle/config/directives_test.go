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

package config

import (
	"reflect"
	"testing"

	bf "github.com/bazelbuild/buildtools/build"
)

func TestDirectives(t *testing.T) {
	for _, tc := range []struct {
		desc, content  string
		wantConfig     Config
		wantDirectives []Directive
	}{
		{
			desc: "empty file",
		}, {
			desc: "locations",
			content: `# gazelle:top

#gazelle:before
foo(
   "foo",  # gazelle:inside
) # gazelle:suffix
#gazelle:after

# gazelle: bottom`,
			wantDirectives: []Directive{
				{Key: "top"},
				{Key: "before"},
				{Key: "after"},
			},
		}, {
			desc:           "empty build_tags",
			content:        `# gazelle:build_tags`,
			wantDirectives: []Directive{{"build_tags", ""}},
		}, {
			desc:           "build_tags",
			content:        `# gazelle:build_tags  foo,bar  `,
			wantConfig:     Config{GenericTags: BuildTags{"foo": true, "bar": true}},
			wantDirectives: []Directive{{"build_tags", "foo,bar"}},
		}, {
			desc:           "build_file_name",
			content:        `# gazelle:build_file_name foo,bar`,
			wantConfig:     Config{ValidBuildFileNames: []string{"foo", "bar"}},
			wantDirectives: []Directive{{"build_file_name", "foo,bar"}},
		},
	} {
		t.Run(tc.desc, func(t *testing.T) {
			f, err := bf.Parse("test.bazel", []byte(tc.content))
			if err != nil {
				t.Fatal(err)
			}

			c := &Config{}
			c.PreprocessTags()
			gotConfig, gotDirectives := ParseDirectives(f, c)
			tc.wantConfig.PreprocessTags()
			if !reflect.DeepEqual(*gotConfig, tc.wantConfig) {
				t.Errorf("bad configuration. got %#v ; want %#v", *gotConfig, tc.wantConfig)
			}
			if !reflect.DeepEqual(gotDirectives, tc.wantDirectives) {
				t.Errorf("bad directives. got %#v ; want %#v", gotDirectives, tc.wantDirectives)
			}
		})
	}
}
