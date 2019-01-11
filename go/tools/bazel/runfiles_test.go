// Copyright 2018 The Bazel Authors.
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

package bazel

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func setenvForTest(key, value string) (cleanup func()) {
	if old, ok := os.LookupEnv(key); ok {
		cleanup = func() { os.Setenv(key, old) }
	} else {
		cleanup = func() { os.Unsetenv(key) }
	}
	os.Setenv(key, value)
	return cleanup
}

func setupResolverForTest() {
	// Prevent initialization code from running.
	runfileResolverOnce.Do(func() {})
	runfileResolver, runfileResolverErr = newRunfilesResolver()
}

func TestManifestRunfiles(t *testing.T) {
	dir, err := NewTmpDir("test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	testStr := "This is a test"
	mappedFilename := filepath.Join(dir, "mapped_file.txt")
	if err := ioutil.WriteFile(mappedFilename, []byte(testStr), 0600); err != nil {
		t.Fatal(err)
	}

	manifestFilename := filepath.Join(dir, "MANIFEST")
	if err := ioutil.WriteFile(manifestFilename, []byte("runfiles/test.txt "+mappedFilename), 0600); err != nil {
		t.Fatal(err)
	}

	cleanupManifestEnv := setenvForTest(RUNFILES_MANIFEST_FILE, manifestFilename)
	defer cleanupManifestEnv()
	cleanupDirEnv := setenvForTest(RUNFILES_DIR, "")
	defer cleanupDirEnv()

	setupResolverForTest()
	if runfileResolverErr != nil {
		t.Fatal(runfileResolverErr)
	}
	if _, ok := runfileResolver.(manifestResolver); !ok {
		t.Error("resolver should be manifest resolver")
	}

	filename, err := Runfile("runfiles/test.txt")
	if err != nil {
		t.Fatal(err)
	}

	d, err := ioutil.ReadFile(filename)
	if err != nil {
		t.Fatal(err)
	}

	if string(d) != testStr {
		t.Errorf("expected %s, got %s", testStr, string(d))
	}
}

func TestDirectoryRunfiles(t *testing.T) {
	dir, err := NewTmpDir("test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	testStr := "This is a test"
	mappedfn := filepath.Join(dir, "runfile.txt")
	if err := ioutil.WriteFile(mappedfn, []byte(testStr), 0600); err != nil {
		t.Fatal(err)
	}

	cleanupManifestEnv := setenvForTest(RUNFILES_MANIFEST_FILE, "")
	defer cleanupManifestEnv()
	cleanupDirEnv := setenvForTest(RUNFILES_DIR, dir)
	defer cleanupDirEnv()

	setupResolverForTest()
	if runfileResolverErr != nil {
		t.Fatal(runfileResolverErr)
	}
	if _, ok := runfileResolver.(directoryResolver); !ok {
		t.Error("resolver should be directory resolver")
	}

	filename, err := Runfile("runfile.txt")
	if err != nil {
		t.Fatal(err)
	}

	d, err := ioutil.ReadFile(filename)
	if err != nil {
		t.Fatal(err)
	}

	if string(d) != testStr {
		t.Errorf("expected %s, got %s", testStr, string(d))
	}
}
