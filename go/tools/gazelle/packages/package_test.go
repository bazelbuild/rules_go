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

package packages_test

import (
	"reflect"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
)

func TestParsePlatformConstraints(t *testing.T) {
	for _, tc := range []struct {
		desc, platforms string
		want            packages.PlatformConstraints
	}{
		{
			desc: "empty",
			want: packages.PlatformConstraints{},
		},
		{
			desc:      "one platform, one tag",
			platforms: "@io_bazel_rules_go//go/platform:linux linux",
			want: packages.PlatformConstraints{
				"@io_bazel_rules_go//go/platform:linux": {"linux": true},
			},
		},
		{
			desc:      "two platforms, two tags",
			platforms: "//:darwin_amd64 darwin,amd64 //:linux_amd64 linux,amd64",
			want: packages.PlatformConstraints{
				"//:darwin_amd64": {"darwin": true, "amd64": true},
				"//:linux_amd64":  {"linux": true, "amd64": true},
			},
		},
	} {
		if got, err := packages.ParsePlatformConstraints(tc.platforms); err != nil {
			t.Errorf("%s: error parsing platforms: %v", tc.desc, err)
		} else if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("%s: got %#v; want %#v", tc.desc, got, tc.want)
		}
	}
}
