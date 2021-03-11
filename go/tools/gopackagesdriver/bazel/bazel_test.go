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

package bazel

import (
	"bytes"
	"errors"
	"io"
	"os"
	"reflect"
	"testing"
)

func TestNew(t *testing.T) {
	b := New()
	if b == nil {
		t.Fatalf("Created a nil object")
	}
}

func TestProcessInfo(t *testing.T) {
	b := &bazel{}
	got, err := b.processInfo(`KEY: VALUE
KEY2: VALUE2
KEY3: value`)
	if err != nil {
		t.Errorf("Error processing info: %s", err)
	}

	expected := map[string]string{
		"KEY":  "VALUE",
		"KEY2": "VALUE2",
		"KEY3": "value",
	}

	if !reflect.DeepEqual(got, expected) {
		t.Errorf("Objects were unequal. Got:\n%s\nExpected:\n%s", got, expected)
	}
}

func TestWriteToStderrAndStdout(t *testing.T) {
	b := &bazel{}
	stdoutBuffer := new(bytes.Buffer)
	stderrBuffer := new(bytes.Buffer)

	// By default it should write to its own pipe.
	b.newCommand("version")
	if reflect.DeepEqual(b.cmd.Stdout, io.MultiWriter(os.Stdout, stderrBuffer)) {
		t.Errorf("Set stdout to os.Stdout and stderrBuffer")
	}
	if reflect.DeepEqual(b.cmd.Stderr, io.MultiWriter(os.Stderr, stdoutBuffer)) {
		t.Errorf("Set stderr to os.Stderr and stdoutBuffer")
	}

	// If set to true it should write to the os version
	b.WriteToStderr(true)
	b.WriteToStdout(true)
	b.newCommand("version")
	if !reflect.DeepEqual(b.cmd.Stdout, io.MultiWriter(os.Stdout, stderrBuffer)) {
		t.Errorf("Didn't set stdout to os.Stdout and stderrBuffer")
	}
	if !reflect.DeepEqual(b.cmd.Stderr, io.MultiWriter(os.Stderr, stdoutBuffer)) {
		t.Errorf("Didn't set stderr to os.Stderr and stdoutBuffer")
	}

	// If set to false it should not write to the os version
	b.WriteToStderr(false)
	b.WriteToStdout(false)
	b.newCommand("version")
	if reflect.DeepEqual(b.cmd.Stdout, io.MultiWriter(os.Stdout, stderrBuffer)) {
		t.Errorf("Set stdout to os.Stdout and stderrBuffer")
	}
	if reflect.DeepEqual(b.cmd.Stderr, io.MultiWriter(os.Stderr, stdoutBuffer)) {
		t.Errorf("Set stderr to os.Stderr and stdoutBuffer")
	}
}

// Test that cancel doesn't NPE if there is no command running.
func TestCancel(t *testing.T) {
	b := New()
	b.Cancel()
}

var bazelNpmPathTests = []struct {
	in string
	out string
	err error
}{
	{"/node_modules/@bazel/ibazel/bin/linux_amd64/ibazel", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazel-linux_x64/bazel-1.2.3-linux_x86_64", nil},
	{"/node_modules/@bazel/ibazel/bin/windows_amd64/ibazel.exe", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazel-windows_x64/bazel-1.2.3-windows_x86_64.exe", nil},
	{"/node_modules/@bazel/ibazel/bin/darwin_amd64/ibazel", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazel-darwin_x64/bazel-1.2.3-darwin_x86_64", nil},
	{"/", "", errors.New("bazel binary not found in @bazel/bazel package")},
}
func TestBazelNpmPath(t *testing.T) {
	// Where bazel gets installed by npm
	bazelNpmDir := os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel"
	
	if err := os.MkdirAll(bazelNpmDir + "/bazel-linux_x64", 0755); err != nil {
		t.Errorf(err.Error())
	}
	if err := os.MkdirAll(bazelNpmDir + "/bazel-windows_x64", 0755); err != nil {
		t.Errorf(err.Error())
	}
	if err := os.MkdirAll(bazelNpmDir + "/bazel-darwin_x64", 0755); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazelNpmDir + "/bazel-linux_x64/bazel-1.2.3-linux_x86_64"); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazelNpmDir + "/bazel-windows_x64/bazel-1.2.3-windows_x86_64.exe"); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazelNpmDir + "/bazel-darwin_x64/bazel-1.2.3-darwin_x86_64"); err != nil {
		t.Errorf(err.Error())
	}
	for _, tt := range bazelNpmPathTests {
		t.Run(tt.in, func(t *testing.T) {
			result, err := bazelNpmPath(os.Getenv("TEST_TMPDIR") + tt.in)
			if result != tt.out {
				t.Errorf("Expected to resolve bazel binary to %v but was %v", tt.out, result)
			}
			if (err != nil && err.Error() != tt.err.Error()) {
				t.Errorf("Expected error %v but was %v", tt.err.Error(), err.Error())
			}
		})
	}
}

var bazeliskNpmPathTests = []struct {
	in  string
	out string
	err error
}{
	{"/node_modules/@bazel/ibazel/bin/linux_amd64/ibazel", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazelisk/bazelisk-linux_amd64", nil},
	{"/node_modules/@bazel/ibazel/bin/windows_amd64/ibazel.exe", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazelisk/bazelisk-windows_amd64.exe", nil},
	{"/node_modules/@bazel/ibazel/bin/darwin_amd64/ibazel", os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazelisk/bazelisk-darwin_amd64", nil},
	{"/", "", errors.New("bazelisk binary not found in @bazel/bazelisk package")},
}

func TestBazeliskNpmPath(t *testing.T) {
	// Where bazel gets installed by npm
	bazeliskNpmDir := os.Getenv("TEST_TMPDIR") + "/node_modules/@bazel/bazelisk"

	if err := os.MkdirAll(bazeliskNpmDir, 0755); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazeliskNpmDir + "/bazelisk-linux_amd64"); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazeliskNpmDir + "/bazelisk-windows_amd64.exe"); err != nil {
		t.Errorf(err.Error())
	}
	if _, err := os.Create(bazeliskNpmDir + "/bazelisk-darwin_amd64"); err != nil {
		t.Errorf(err.Error())
	}
	for _, tt := range bazeliskNpmPathTests {
		t.Run(tt.in, func(t *testing.T) {
			result, err := bazeliskNpmPath(os.Getenv("TEST_TMPDIR") + tt.in)
			if result != tt.out {
				t.Errorf("Expected to resolve bazelisk binary from %s to %v but was %v", tt.in, tt.out, result)
			}
			if err != nil && tt.err != nil && err.Error() != tt.err.Error() {
				t.Errorf("Expected error %v but was %v", tt.err.Error(), err.Error())
			}
		})
	}
}
