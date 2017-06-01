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
	"reflect"
	"testing"
)

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
	f := func(s string) string {
		return s + "x"
	}
	ps := PlatformStrings{
		Generic: []string{"a"},
		Platform: map[string][]string{
			"linux": []string{"b"},
		},
	}
	got := ps.Map(f)
	want := PlatformStrings{
		Generic: []string{"ax"},
		Platform: map[string][]string{
			"linux": []string{"bx"},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %#v; want %#v", got, want)
	}
}
