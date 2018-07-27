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

package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

var (
	// cgoEnvVars is the list of all cgo environment variable
	cgoEnvVars = []string{"CGO_CFLAGS", "CGO_CXXFLAGS", "CGO_CPPFLAGS", "CGO_LDFLAGS"}
	// cgoAbsEnvFlags are all the flags that need absolute path in cgoEnvVars
	cgoAbsEnvFlags = []string{"-I", "-L", "-isysroot", "-isystem", "-iquote", "-include", "-gcc-toolchain", "--sysroot"}
)

// env holds a small amount of Go environment and toolchain information
// which is common to multiple builders. Most Bazel-agnostic build information
// is collected in go/build.Default though.
//
// See ./README.rst for more information about handling arguments and
// environment variables.
type env struct {
	// sdk is the path to the Go SDK, which contains tools for the host
	// platform. This may be different than GOROOT.
	sdk string

	// verbose indicates whether subprocess command lines should be printed.
	verbose bool
}

// envFlags registers flags common to multiple builders and returns an env
// configured with those flags.
func envFlags(flags *flag.FlagSet) *env {
	env := &env{}
	flags.StringVar(&env.sdk, "sdk", "", "Path to the Go SDK.")
	flags.Var(&tagFlag{}, "tags", "List of build tags considered true.")
	flags.BoolVar(&env.verbose, "v", false, "Whether subprocess command lines should be printed")
	return env
}

// checkFlags checks whether env flags were set to valid values. checkFlags
// should be called after parsing flags.
func (e *env) checkFlags() error {
	if e.sdk == "" {
		return errors.New("-sdk was not set")
	}
	return nil
}

// goTool returns a slice containing the path to an executable at
// $GOROOT/pkg/$GOOS_$GOARCH/$tool and additional arguments.
func (e *env) goTool(tool string, args ...string) []string {
	platform := fmt.Sprintf("%s_%s", runtime.GOOS, runtime.GOARCH)
	toolPath := filepath.Join(e.sdk, "pkg", "tool", platform, tool)
	if runtime.GOOS == "windows" {
		toolPath += ".exe"
	}
	return append([]string{toolPath}, args...)
}

// goCmd returns a slice containing the path to the go executable
// and additional arguments.
func (e *env) goCmd(cmd string, args ...string) []string {
	exe := filepath.Join(e.sdk, "bin", "go")
	if runtime.GOOS == "windows" {
		exe += ".exe"
	}
	return append([]string{exe, cmd}, args...)
}

// runCommand executes a subprocess that inherits stdout, stderr, and the
// environment from this process.
func (e *env) runCommand(args []string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return runAndLogCommand(cmd, e.verbose)
}

// runCommandToFile executes a subprocess and writes the output to the given
// writer.
func (e *env) runCommandToFile(w io.Writer, args []string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	return runAndLogCommand(cmd, e.verbose)
}

func absEnv(envNameList []string, argList []string) error {
	for _, envName := range envNameList {
		splitedEnv := strings.Fields(os.Getenv(envName))
		absArgs(splitedEnv, argList)
		if err := os.Setenv(envName, strings.Join(splitedEnv, " ")); err != nil {
			return err
		}
	}
	return nil
}

func runAndLogCommand(cmd *exec.Cmd, verbose bool) error {
	if verbose {
		formatCommand(os.Stderr, cmd)
	}
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running subcommand: %v", err)
	}
	return nil
}

// splitArgs splits a list of command line arguments into two parts: arguments
// that should be interpreted by the builder (before "--"), and arguments
// that should be passed through to the underlying tool (after "--").
// A group consisting of a single argument that is prefixed with an '@', is
// treated as a pointer to a params file, which is read and its contents used
// as the arguments.
func splitArgs(args []string) (builderArgs []string, toolArgs []string) {
	for i, arg := range args {
		if arg == "--" {

			return readParamsFile(args[:i]), readParamsFile(args[i+1:])
		}
	}
	return readParamsFile(args), nil
}

// readParamsFile replaces the passed in slice with the contents of a params
// file, if the slice is a single string that starts with an '@'.
// Errors reading the file are ignored and the original slice is returned.
func readParamsFile(args []string) []string {
	if len(args) == 1 && strings.HasPrefix(args[0], "@") {
		content, err := ioutil.ReadFile(args[0][1:])
		if err == nil {
			args = strings.Split(string(content), "\n")
		}
	}
	return args
}

// abs returns the absolute representation of path. Some tools/APIs require
// absolute paths to work correctly. Most notably, golang on Windows cannot
// handle relative paths to files whose absolute path is > ~250 chars, while
// it can handle absolute paths. See http://goo.gl/eqeWjm.
func abs(path string) string {
	if abs, err := filepath.Abs(path); err != nil {
		return path
	} else {
		return abs
	}
}

// absArgs applies abs to strings that appear in args. Only paths that are
// part of options named by flags are modified.
func absArgs(args []string, flags []string) {
	absNext := false
	for i := range args {
		if absNext {
			args[i] = abs(args[i])
			absNext = false
			continue
		}
		for _, f := range flags {
			if !strings.HasPrefix(args[i], f) {
				continue
			}
			possibleValue := args[i][len(f):]
			if len(possibleValue) == 0 {
				absNext = true
				break
			}
			separator := ""
			if possibleValue[0] == '=' {
				possibleValue = possibleValue[1:]
				separator = "="
			}
			args[i] = fmt.Sprintf("%s%s%s", f, separator, abs(possibleValue))
			break
		}
	}
}

// formatCommand writes cmd to w in a format where it can be pasted into a
// shell. Spaces in environment variables and arguments are escaped as needed.
func formatCommand(w io.Writer, cmd *exec.Cmd) {
	quoteIfNeeded := func(s string) string {
		if strings.IndexByte(s, ' ') < 0 {
			return s
		}
		return strconv.Quote(s)
	}
	quoteEnvIfNeeded := func(s string) string {
		eq := strings.IndexByte(s, '=')
		if eq < 0 {
			return s
		}
		key, value := s[:eq], s[eq+1:]
		if strings.IndexByte(value, ' ') < 0 {
			return s
		}
		return fmt.Sprintf("%s=%s", key, strconv.Quote(value))
	}

	environ := cmd.Env
	if environ == nil {
		environ = os.Environ()
	}
	for _, e := range environ {
		fmt.Fprintf(w, "%s \\\n", quoteEnvIfNeeded(e))
	}

	sep := ""
	for _, arg := range cmd.Args {
		fmt.Fprintf(w, "%s%s", sep, quoteIfNeeded(arg))
		sep = " "
	}
	fmt.Fprint(w, "\n")
}
