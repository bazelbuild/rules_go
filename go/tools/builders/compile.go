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
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
)

func run(args []string) error {
	unfiltered := multiFlag{}
	deps := multiFlag{}
	search := multiFlag{}
	importmap := multiFlag{}
	flags := flag.NewFlagSet("compile", flag.ContinueOnError)
	goenv := envFlags(flags)
	flags.Var(&unfiltered, "src", "A source file to be filtered and compiled")
	flags.Var(&deps, "dep", "Import path of a direct dependency")
	flags.Var(&search, "I", "Search paths of a direct dependency")
	flags.Var(&importmap, "importmap", "Import maps of a direct dependency")
	trimpath := flags.String("trimpath", "", "The base of the paths to trim")
	output := flags.String("o", "", "The output object file to write")
	packageList := flags.String("package_list", "", "The file containing the list of standard library packages")
	testfilter := flags.String("testfilter", "off", "Controls test package filtering")
	// process the args
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.update(); err != nil {
		return err
	}

	var matcher func(f *goMetadata) bool
	switch *testfilter {
	case "off":
		matcher = func(f *goMetadata) bool {
			return true
		}
	case "only":
		matcher = func(f *goMetadata) bool {
			return strings.HasSuffix(f.pkg, "_test")
		}
	case "exclude":
		matcher = func(f *goMetadata) bool {
			return !strings.HasSuffix(f.pkg, "_test")
		}
	default:
		return fmt.Errorf("Invalid test filter %q", *testfilter)
	}
	// apply build constraints to the source list
	bctx := goenv.BuildContext()
	all, err := readFiles(bctx, unfiltered)
	if err != nil {
		return err
	}
	files := []*goMetadata{}
	for _, f := range all {
		if matcher(f) {
			files = append(files, f)
		}
	}
	if len(files) <= 0 {
		return ioutil.WriteFile(*output, []byte(""), 0644)
	}

	goargs := []string{"tool", "compile"}
	goargs = append(goargs, "-trimpath", abs(*trimpath))
	for _, path := range search {
		goargs = append(goargs, "-I", abs(path))
	}
	strictdeps := deps
	for _, mapping := range importmap {
		i := strings.Index(mapping, "=")
		if i < 0 {
			return fmt.Errorf("Invalid importmap %v: no = separator", mapping)
		}
		source := mapping[:i]
		actual := mapping[i+1:]
		if source == "" || actual == "" || source == actual {
			continue
		}
		goargs = append(goargs, "-importmap", mapping)
		strictdeps = append(strictdeps, source)
	}
	goargs = append(goargs, "-pack", "-o", *output)
	goargs = append(goargs, flags.Args()...)
	for _, f := range files {
		goargs = append(goargs, f.filename)
	}

	// Check that the filtered sources don't import anything outside of deps.
	if err := checkDirectDeps(bctx, files, strictdeps, *packageList); err != nil {
		return err
	}

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

func checkDirectDeps(bctx build.Context, files []*goMetadata, deps []string, packageList string) error {
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
	for _, f := range files {
		for _, path := range f.imports {
			if path == "C" || stdlib[path] || isRelative(path) {
				// Standard paths don't need to be listed as dependencies (for now).
				// Relative paths aren't supported yet. We don't emit errors here, but
				// they will certainly break something else.
				continue
			}
			if !depSet[path] {
				errs = append(errs, fmt.Errorf("%s: import of %s, which is not a direct dependency", f.filename, path))
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
