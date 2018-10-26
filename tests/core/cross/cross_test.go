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

package cross_test

import (
	"flag"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

type check struct {
	file *string
	info []string
}

var darwin = flag.String("darwin", "", "The darwin binary")
var linux = flag.String("linux", "", "The linux binary")
var windows = flag.String("windows", "", "The windows binary")

var checks = []check{
	{darwin, []string{
		"Mach-O",
		"64-bit",
		"executable",
		"x86_64",
	}},
	{linux, []string{
		"ELF",
		"64-bit",
		"executable",
		"x86-64",
	}},
	{windows, []string{
		"PE32+",
		"Windows",
		"executable",
		"console",
		"x86-64",
	}},
}

func TestCross(t *testing.T) {
	for _, c := range checks {
		path, err := bazel.Runfile(*c.file)
		if err != nil {
			t.Fatalf("Could not find runfile %s: %q", *c.file, err)
		}

		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Fatalf("Missing binary %v", path)
		}
		file, err := filepath.EvalSymlinks(path)
		if err != nil {
			t.Fatalf("Invalid filename %v", path)
		}
		cmd := exec.Command("file", file)
		cmd.Stderr = os.Stderr
		res, err := cmd.Output()
		if err != nil {
			t.Fatalf("failed running 'file': %v", err)
		}
		output := string(res)
		if index := strings.Index(output, ":"); index >= 0 {
			output = output[index+1:]
		}
		output = strings.TrimSpace(output)
		for _, info := range c.info {
			if !strings.Contains(output, info) {
				t.Errorf("incorrect type for %v\nExpected %v\nGot      %v", file, info, output)
			}
		}
	}
}
