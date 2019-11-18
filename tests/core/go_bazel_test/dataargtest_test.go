// Copyright 2019 The Bazel Authors. All rights reserved.
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
	"flag"
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

var (
	binaryPath = flag.String("binaryPath", "", "")
	setUpRan   = false
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- root.txt --
Hello world!
-- nested/file.txt --
Hello world!`,
		SetUp: func() error {
			setUpRan = true
			return nil
		},
	})
}

// Tests that go_bazel_test keeps includes data files correctly and doesn't mess
// up on `args` that include `$(location ...)` calls.
func TestGoldenPath(t *testing.T) {
	bp, err := bazel.Runfile(*binaryPath)
	if err != nil {
		t.Fatalf("unable to get the runfile path %#v: %s", *binaryPath, err)
	}

	tests := map[string]string{
		"Go binary file":          bp,
		"Text file in root":       "root.txt",
		"Text file in nested dir": "nested/file.txt",
	}

	for name, f := range tests {
		_, err = os.Stat(f)
		if err != nil {
			t.Fatalf("unable to stat %s file (%q): %s", name, f, err)
		}
	}

	if setUpRan == false {
		t.Fatal("setUp should have been executed but was not")
	}
}
