// Copyright 2018 The Bazel Authors. All rights reserved.
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
	"bufio"
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"syscall"
)

// makeHermetic executes the tool on the command line, filtering out any
// -buildid arguments and rewriting cgo files to not contain absolute paths.
// It is intended to be used with -toolexec when building the standard library.
// See stdlib.go for the usage and further comments.
func makeHermetic(args []string) error {
	isCgo := filepath.Base(args[0]) == "cgo"
	var objdir string
	newArgs := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "-buildid" {
			i++
			continue
		} else if isCgo && arg == "-objdir" {
			objdir = args[i+1]
		}
		newArgs = append(newArgs, arg)
	}
	if runtime.GOOS == "windows" || isCgo {
		cmd := exec.Command(newArgs[0], newArgs[1:]...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			return err
		}
		if isCgo {
			// Rewrite cgo files to not contain absolute paths in ldflag
			// comments.
			return rewriteCgoFiles(objdir)
		} else {
			return nil
		}
	} else {
		return syscall.Exec(newArgs[0], newArgs, os.Environ())
	}
}

func rewriteCgoFiles(objdir string) error {
	cgoGoTypes := filepath.Join(objdir, "_cgo_gotypes.go")
	f, err := os.OpenFile(cgoGoTypes, os.O_RDWR, 0)
	if err != nil {
		// If the file doesn't exist for whatever reason, we don't need to
		// rewrite it.
		return nil
	}
	defer f.Close()
	fixedData, err := rewriteCgoLdflagComments(f)
	if err != nil {
		return err
	}
	if err = f.Truncate(0); err != nil {
		return err
	}
	if _, err = f.Seek(0, 0); err != nil {
		return err
	}
	if _, err = f.Write(fixedData); err != nil {
		return err
	}
	return nil
}

func rewriteCgoLdflagComments(f *os.File) ([]byte, error) {
	bazelWd := []byte(os.Getenv("BAZEL_WORKING_DIRECTORY") + "/")

	// Replace absolute paths in //go:cgo_ldflag comments with relative paths.
	// We need to pass absolute paths to the "go install" command for building
	// the standard library, but we want to strip them from the generated files
	// to make the build hermetic.
	s := bufio.NewScanner(f)
	var buf bytes.Buffer
	for s.Scan() {
		line := s.Bytes()
		if bytes.HasPrefix(line, []byte("//go:cgo_ldflag ")) {
			line = bytes.ReplaceAll(line, bazelWd, []byte{})
		}
		buf.Write(line)
		buf.WriteByte('\n')
	}
	if err := s.Err(); err != nil {
		return []byte{}, err
	}
	return buf.Bytes(), nil
}
