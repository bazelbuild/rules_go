// Copyright 2021 The Bazel Authors. All rights reserved.
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
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// runForError runs a command without showing its output. If the command fails,
// runForError returns an error containing its stderr.
func runForError(ctx context.Context, dir string, name string, args ...string) error {
	stderr := &bytes.Buffer{}
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = envWithoutBazel()
	cmd.Dir = dir
	cmd.Stdout = nil
	cmd.Stderr = stderr
	err := cmd.Run()
	return cleanCmdError(err, name, args, stderr.Bytes())
}

// runForOutput runs a command and returns its output. If the command fails,
// runForOutput returns an error containing its stderr. The command's output
// is returned whether it failed or not.
func runForOutput(ctx context.Context, dir string, name string, args ...string) ([]byte, error) {
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = envWithoutBazel()
	cmd.Dir = dir
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	err := cmd.Run()
	return stdout.Bytes(), cleanCmdError(err, name, args, stderr.Bytes())
}

// envWithoutBazel runs the current process's environment without variables
// starting with "BUILD_" added by 'bazel run'. These can confuse subprocesses.
func envWithoutBazel() []string {
	env := os.Environ()
	filtered := make([]string, 0, len(env))
	for _, e := range env {
		if strings.HasPrefix(e, "BUILD_") {
			continue
		}
		filtered = append(filtered, e)
	}
	return filtered
}

// cleanCmdError wraps an error returned by exec.Cmd.Run with the command that
// was run and its stderr output.
func cleanCmdError(err error, name string, args []string, stderr []byte) error {
	if err == nil {
		return nil
	}
	return &commandError{
		argv: append([]string{name}, args...),
		err:  err,
	}
}

type commandError struct {
	argv   []string
	stderr []byte
	err    error
}

func (e *commandError) Error() string {
	return fmt.Sprintf("running %s: %v\n%s", strings.Join(e.argv, " "), e.err, bytes.TrimSpace(e.stderr))
}

func (e *commandError) Unwrap() error {
	return e.err
}
