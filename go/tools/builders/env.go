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
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// env holds a small amount of Go environment and toolchain information
// which is common to multiple builders. Most Bazel-agnostic build information
// is collected in go/build.Default though.
//
// See ./README.rst for more information about handling arguments and
// environment variables.
type env struct {
	// go_ is the path to the go executable
	go_ string

	// verbose indicates whether subprocess command lines should be printed.
	verbose bool
}

// envFlags registers flags common to multiple builders and returns an env
// configured with those flags.
func envFlags(flags *flag.FlagSet) *env {
	env := &env{}
	flags.StringVar(&env.go_, "go", "", "The path to the go tool.")
	flags.Var(&tagFlag{}, "tags", "List of build tags considered true.")
	flags.BoolVar(&env.verbose, "v", false, "Whether subprocess command lines should be printed")
	return env
}

// checkFlags checks whether env flags were set to valid values. checkFlags
// should be called after parsing flags.
func (e *env) checkFlags() error {
	if e.go_ == "" {
		return errors.New("-go was not specified")
	}
	return nil
}

// runGoCommand executes a subprocess through the go tool. The subprocess will
// inherit stdout, stderr, and the environment from this process.
func (e *env) runGoCommand(goargs []string) error {
	cmd := exec.Command(e.go_, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return runAndLogCommand(cmd, e.verbose)
}

// runGoCommandToFile executes a subprocess through the go tool and writes
// the output to the given writer.
func (e *env) runGoCommandToFile(w io.Writer, goargs []string) error {
	cmd := exec.Command(e.go_, goargs...)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	return runAndLogCommand(cmd, e.verbose)
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
func splitArgs(args []string) (builderArgs []string, toolArgs []string) {
	for i, arg := range args {
		if arg == "--" {
			return args[:i], args[i+1:]
		}
	}
	return args, nil
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
		if !strings.HasPrefix(args[i], "-") {
			continue
		}
		var flag, value string
		var separate bool
		if j := strings.IndexByte(args[i], '='); j >= 0 {
			flag = args[i][:j]
			value = args[i][j+1:]
		} else {
			separate = true
			flag = args[i]
		}
		flag = strings.TrimLeft(args[i], "-")
		for _, f := range flags {
			if flag != f {
				continue
			}
			if separate {
				absNext = true
			} else {
				value = abs(value)
				args[i] = fmt.Sprintf("-%s=%s", flag, value)
			}
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
