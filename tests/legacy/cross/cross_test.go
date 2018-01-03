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
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

type check struct {
	file string
	info []string
}

var checks = []check{
	{"darwin_amd64_pure_stripped/cross", []string{
		"Mach-O",
		"64-bit",
		"executable",
		"x86_64",
	}},
	{"linux_amd64_pure_stripped/cross", []string{
		"ELF",
		"64-bit",
		"executable",
		"x86-64",
	}},
	{"windows_amd64_pure_stripped/cross.exe", []string{
		"PE32+",
		"Windows",
		"executable",
		"console",
		"x86-64",
	}},
}

func TestCross(t *testing.T) {
	for _, c := range checks {
		if _, err := os.Stat(c.file); os.IsNotExist(err) {
			t.Fatalf("Missing binary %v", c.file)
		}
		file, err := filepath.EvalSymlinks(c.file)
		if err != nil {
			t.Fatalf("Invalid filename %v", file)
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
