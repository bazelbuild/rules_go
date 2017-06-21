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

// compile compiles .go files with "go tool compile". It is invoked by the
// Go rules as an action.
package main

import (
	"fmt"
	"go/build"
	"go/parser"
	"go/token"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func run(args []string) error {
	// process the args
	if len(args) < 2 {
		return fmt.Errorf("Usage: compile gotool [-dep importpath ...] [sources] -- <extra options>")
	}
	gotool := args[0]
	args = args[1:]
	sources := []string{}
	goopts := []string{}
	deps := []string{}
	bctx := build.Default
	bctx.CgoEnabled = true
	depNext := false
argsLoop:
	for i, s := range args {
		switch {
		case s == "--":
			goopts = args[i+1:]
			break argsLoop
		case depNext:
			deps = append(deps, s)
			depNext = false
		case s == "-dep":
			depNext = true
		default:
			sources = append(sources, s)
		}
	}

	// apply build constraints to the source list
	sources, err := filterFiles(bctx, sources)
	if err != nil {
		return err
	}
	if len(sources) <= 0 {
		return fmt.Errorf("no unfiltered sources to compile")
	}

	// Check that the filtered sources don't import anything outside of deps.
	if err := checkDirectDeps(bctx, sources, deps); err != nil {
		return err
	}

	// Now we need to abs include and trim paths
	needAbs := false
	for i, arg := range goopts {
		switch {
		case needAbs:
			needAbs = false
			abs, err := filepath.Abs(arg)
			if err == nil {
				goopts[i] = abs
			}
		case arg == "-I":
			needAbs = true
		case arg == "-trimpath":
			needAbs = true
		default:
			needAbs = false
		}
	}

	goargs := append([]string{"tool", "compile"}, goopts...)
	goargs = append(goargs, sources...)
	cmd := exec.Command(gotool, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running compiler: %v", err)
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func checkDirectDeps(bctx build.Context, sources, deps []string) error {
	depSet := make(map[string]bool)
	for _, d := range deps {
		depSet[d] = true
	}

	var errs depsError
	fs := token.NewFileSet()
	for _, s := range sources {
		f, err := parser.ParseFile(fs, s, nil, parser.ImportsOnly)
		if err != nil {
			// Let the compiler report parse errors.
			continue
		}
		for _, i := range f.Imports {
			path, err := strconv.Unquote(i.Path.Value)
			if err != nil {
				// Should never happen, but let the compiler deal with it.
				continue
			}
			if path == "C" || isStandard(bctx, path) || isRelative(path) {
				// Standard paths don't need to be listed as dependencies (for now).
				// Relative paths aren't supported yet. We don't emit errors here, but
				// they will certainly break something else.
				continue
			}
			if !depSet[path] {
				errs = append(errs, fmt.Errorf("%s: import of %s, which is not a direct dependency", s, path))
			}
		}
	}
	if len(errs) > 0 {
		return errs
	}
	return nil
}

type depsError []error

var _ error = depsError(nil)

func (e depsError) Error() string {
	errorStrings := make([]string, len(e))
	for i, err := range e {
		errorStrings[i] = err.Error()
	}
	return "missing strict dependencies:\n\t" + strings.Join(errorStrings, "\n\t")
}

func isStandard(bctx build.Context, path string) bool {
	rootPath := filepath.Join(bctx.GOROOT, "src", filepath.FromSlash(path))
	st, err := os.Stat(rootPath)
	return err == nil && st.IsDir()
}

func isRelative(path string) bool {
	return strings.HasPrefix(path, "./") || strings.HasPrefix(path, "../")
}
