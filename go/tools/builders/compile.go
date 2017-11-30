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
	"flag"
	"fmt"
	"go/build"
	"go/parser"
	"go/token"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

func run(args []string) error {
	unfiltered := multiFlag{}
	deps := multiFlag{}
	search := multiFlag{}
	flags := flag.NewFlagSet("compile", flag.ContinueOnError)
	goenv := envFlags(flags)
	flags.Var(&unfiltered, "src", "A source file to be filtered and compiled")
	flags.Var(&deps, "dep", "Import path of a direct dependency")
	flags.Var(&search, "I", "Search paths of a direct dependency")
	trimpath := flags.String("trimpath", "", "The base of the paths to trim")
	output := flags.String("o", "", "The output object file to write")
	packageList := flags.String("package_list", "", "The file containing the list of standard library packages")
	// process the args
	if err := flags.Parse(args); err != nil {
		return err
	}

	// apply build constraints to the source list
	bctx := goenv.BuildContext()
	sources, err := filterFiles(bctx, unfiltered)
	if err != nil {
		return err
	}
	if len(sources) <= 0 {
		return ioutil.WriteFile(*output, []byte(""), 0644)
	}

	// Check that the filtered sources don't import anything outside of deps.
	if err := checkDirectDeps(bctx, sources, deps, *packageList); err != nil {
		return err
	}

	goargs := []string{"tool", "compile"}
	goargs = append(goargs, "-trimpath", abs(*trimpath))
	for _, path := range search {
		goargs = append(goargs, "-I", abs(path))
	}
	goargs = append(goargs, "-pack", "-o", *output)
	goargs = append(goargs, flags.Args()...)
	goargs = append(goargs, sources...)
	env := os.Environ()
	env = append(env, goenv.Env()...)
	cmd := exec.Command(goenv.Go, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
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

func checkDirectDeps(bctx build.Context, sources, deps []string, packageList string) error {
	packagesTxt, err := ioutil.ReadFile(packageList)
	if err != nil {
		log.Fatal(err)
	}
	stdlib := map[string]bool{}
	for _, line := range strings.Split(string(packagesTxt), "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			stdlib[line] = true
		}
	}

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
			if path == "C" || stdlib[path] || isRelative(path) {
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

func isRelative(path string) bool {
	return strings.HasPrefix(path, "./") || strings.HasPrefix(path, "../")
}
