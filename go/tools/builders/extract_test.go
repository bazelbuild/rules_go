// Copyright 2017 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package main

import (
	"io/ioutil"
	"os"
	"testing"
)

func TestExtract(t *testing.T) {
	for _, spec := range []struct {
		src  string
		want string
	}{
		// These example inputs also illustrate the reason why we
		// cannot simply replace extractPackage with sed(1) or awk(1).
		{
			src:  `package main`,
			want: "main",
		},
		{
			src:  `package /* package another */ example // package yetanother`,
			want: "example",
		},
	} {
		f, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "example-go-src")
		if err != nil {
			t.Fatal(err)
		}
		defer os.Remove(f.Name())
		if err := ioutil.WriteFile(f.Name(), []byte(spec.src), 0644); err != nil {
			t.Fatal(err)
		}

		name, err := extractPackage(f.Name())
		if err != nil {
			t.Errorf("extractPackage(%q) failed with %v; want success; content = %q", f.Name(), err, spec.src)
		}
		if got, want := name, spec.want; got != want {
			t.Errorf("extractPackage(%q) = %q; want %q; content = %q", f.Name(), got, want, spec.src)
		}
	}
}
