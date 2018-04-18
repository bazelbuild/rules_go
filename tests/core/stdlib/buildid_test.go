// +build go1.10

/* Copyright 2018 The Bazel Authors. All rights reserved.

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

package buildid_test

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestEmptyBuildID(t *testing.T) {
	// Locate fmt.a (any .a file in the stdlib will do) and the buildid tool.
	// The path may vary depending on the platform and architecture, so we
	// just do a search.
	var fmtPath, buildidPath string
	done := errors.New("done")
	var visit filepath.WalkFunc
	visit = func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if (info.Mode() & os.ModeType) == os.ModeSymlink {
			path, err = filepath.EvalSymlinks(path)
			if err != nil {
				return err
			}
			return filepath.Walk(path, visit)
		}
		if filepath.Base(path) == "fmt.a" {
			fmtPath = path
		}
		if filepath.Base(path) == "buildid" && (info.Mode()&0111) != 0 {
			buildidPath = path
		}
		if fmtPath != "" && buildidPath != "" {
			return done
		}
		return nil
	}
	if err := filepath.Walk(".", visit); err == nil {
		t.Fatal("could not locate stdlib ROOT file")
	} else if err != done {
		t.Fatal(err)
	}
	if buildidPath == "" {
		t.Fatal("buildid not found")
	}
	if fmtPath == "" {
		t.Fatal("fmt.a not found")
	}

	// Equivalent to: go tool buildid fmt.a
	// It's an error if this produces any output.
	cmd := exec.Command(buildidPath, fmtPath)
	out, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	if len(bytes.TrimSpace(out)) > 0 {
		t.Errorf("%s: unexpected buildid: %s", fmtPath, out)
	}
}
