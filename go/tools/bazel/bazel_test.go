// Copyright 2017 Google Inc.
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
	"os"
	"testing"
)

func TestRunfile(t *testing.T) {
	file := "go/tools/bazel/README.md"
	runfile, err := Runfile(file)
	if err != nil {
		t.Errorf("When reading file %s got error %s", file, err)
	}

	// Check that the file actually exist
	if _, err := os.Stat(runfile); err != nil {
		t.Errorf("File found by runfile doesn't exist")
	}
}

func TestRunfilesPath(t *testing.T) {
	path, err := RunfilesPath()
	if err != nil {
		t.Errorf("Error finding runfiles path: %s", err)
	}

	if path == "" {
		t.Errorf("Runfiles path is empty: %s", path)
	}
}

func TestNewTmpDir(t *testing.T) {
	//prefix := "new/temp/dir"
	prefix := "demodir"
	tmpdir, err := NewTmpDir(prefix)
	if err != nil {
		t.Errorf("When creating temp dir %s got error %s", prefix, err)
	}

	// Check that the tempdir actually exist
	if _, err := os.Stat(tmpdir); err != nil {
		t.Errorf("New tempdir (%s) not created. Got error %s", tmpdir, err)
	}
}

func TestTestTmpDir(t *testing.T) {
	if TestTmpDir() == "" {
		t.Errorf("TestTmpDir (TEST_TMPDIR) was left empty")
	}
}

func TestTestWorkspace(t *testing.T) {
	workspace, err := TestWorkspace()

	if workspace == "" {
		t.Errorf("Workspace is left empty")
	}

	if err != nil {
		t.Errorf("Unable to get workspace with error %s", err)
	}
}

func TestTestWorkspaceWithoutDefaultSet(t *testing.T) {
	if oldVal, ok := os.LookupEnv(TEST_WORKSPACE); ok {
		defer os.Setenv(TEST_WORKSPACE, oldVal)
	} else {
		t.Errorf("Terrible things are happening. You can't read env variables")
	}
	os.Unsetenv(TEST_WORKSPACE)

	workspace, err := TestWorkspace()

	if workspace != "" {
		t.Errorf("Workspace should be left empty but was: %s", workspace)
	}

	if err == nil {
		t.Errorf("Expected error but instead passed")
	}
}

func TestTestWorkspaceWithDefaultSet(t *testing.T) {
	if oldVal, ok := os.LookupEnv(TEST_WORKSPACE); ok {
		defer os.Setenv(TEST_WORKSPACE, oldVal)
	} else {
		t.Errorf("Terrible things are happening. You can't read env variables")
	}
	os.Unsetenv(TEST_WORKSPACE)

	SetDefaultTestWorkspace("default_value")
	workspace, err := TestWorkspace()

	if workspace == "" {
		t.Errorf("Workspace is left empty")
	}

	if err != nil {
		t.Errorf("Unable to get workspace with error %s", err)
	}
}
