// Copyright 2018 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package runfiles

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func fakeGetenv(env map[string]string) func(string) string {
	return func(key string) string {
		return env[key]
	}
}

func TestManifestRunfiles(t *testing.T) {
	dir, err := ioutil.TempDir("", "test")
	if err != nil {
		t.Fatal(err)
	}

	defer os.RemoveAll(dir)

	testStr := "This is a test"
	mappedfn := filepath.Join(dir, "mapped_file.txt")
	if err := ioutil.WriteFile(mappedfn, []byte(testStr), 0600); err != nil {
		t.Fatal(err)
	}

	manifestfn := filepath.Join(dir, "MANIFEST")
	if err := ioutil.WriteFile(manifestfn, []byte("runfiles/test.txt "+mappedfn), 0600); err != nil {
		t.Fatal(err)
	}

	resolver, err := newResolverWithGetenv(fakeGetenv(map[string]string{
		RUNFILES_MANIFEST_FILE: manifestfn,
	}))
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := resolver.(manifestResolver); !ok {
		t.Error("resolver should be manifest resolver")
	}

	fn, err := resolver.Resolve("runfiles/test.txt")
	if err != nil {
		t.Fatal(err)
	}

	d, err := ioutil.ReadFile(fn)
	if err != nil {
		t.Fatal(err)
	}

	if string(d) != testStr {
		t.Errorf("expected %s, got %s", testStr, string(d))
	}
}

func TestDirectoryRunfiles(t *testing.T) {
	dir, err := ioutil.TempDir("", "test")
	if err != nil {
		t.Fatal(err)
	}

	defer os.RemoveAll(dir)

	testStr := "This is a test"
	mappedfn := filepath.Join(dir, "runfile.txt")
	if err := ioutil.WriteFile(mappedfn, []byte(testStr), 0600); err != nil {
		t.Fatal(err)
	}

	resolver, err := newResolverWithGetenv(fakeGetenv(map[string]string{
		RUNFILES_DIR: dir,
	}))
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := resolver.(directoryResolver); !ok {
		t.Error("resolver should be directory resolver")
	}

	fn, err := resolver.Resolve("runfile.txt")
	if err != nil {
		t.Fatal(err)
	}

	d, err := ioutil.ReadFile(fn)
	if err != nil {
		t.Fatal(err)
	}

	if string(d) != testStr {
		t.Errorf("expected %s, got %s", testStr, string(d))
	}
}
