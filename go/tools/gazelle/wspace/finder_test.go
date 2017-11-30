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
package wspace

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

type testCase struct {
	dir  string
	want string // "" means should fail
}

func TestFind(t *testing.T) {
	tmp, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmp)
	if parent, err := Find(tmp); err == nil {
		t.Skipf("WORKSPACE visible in parent %q of tmp %q", parent, tmp)
	}

	if err := os.MkdirAll(filepath.Join(tmp, "base", "sub"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := ioutil.WriteFile(filepath.Join(tmp, "base", workspaceFile), nil, 0755); err != nil {
		t.Fatal(err)
	}

	tmpBase := filepath.Join(tmp, "base")

	for _, tc := range []testCase{
		{tmpBase, tmpBase},
		{filepath.Join(tmpBase, "sub"), tmpBase}} {

		d, err := Find(tc.dir)
		if err != nil {
			if tc.want != "" {
				t.Errorf("Find(%q) want %q, got %v", tc.dir, tc.want, err)
			}
			continue
		}
		if d != tc.want {
			t.Errorf("Find(%q) got %q, want %q", tc.dir, d, tc.want)
		}
	}
}
