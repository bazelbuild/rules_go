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
	"bytes"
	"flag"
	"fmt"
	"go/build"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
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
	absOutput := abs(*output) // required to work with long paths on Windows

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
	if len(files) == 0 {
		// We need to run the compiler to create a valid archive, even if there's
		// nothing in it. GoPack will complain if we try to add assembly or cgo
		// objects.
		emptyPath := filepath.Join(abs(*trimpath), "_empty.go")
		if err := ioutil.WriteFile(emptyPath, []byte("package empty\n"), 0666); err != nil {
			return err
		}
		files = append(files, &goMetadata{filename: emptyPath})
	}

	goargs := []string{"tool", "compile"}
	if goenv.shared {
		goargs = append(goargs, "-shared")
	}
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
	goargs = append(goargs, "-pack", "-o", absOutput)
	goargs = append(goargs, flags.Args()...)
	for _, f := range files {
		goargs = append(goargs, f.filename)
	}

	// Check that the filtered sources don't import anything outside of deps.
	if err := checkDirectDeps(bctx, files, strictdeps, *packageList); err != nil {
		return err
	}

	cmd := exec.Command(goenv.Go, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = goenv.Env()
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running compiler: %v", err)
	}
	return nil
}

func main() {
	log.SetFlags(0) // no timestamp
	log.SetPrefix("GoCompile: ")
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

	derr := depsError{known: deps}
	for _, f := range files {
		for _, path := range f.imports {
			if path == "C" || stdlib[path] || isRelative(path) {
				// Standard paths don't need to be listed as dependencies (for now).
				// Relative paths aren't supported yet. We don't emit errors here, but
				// they will certainly break something else.
				continue
			}
			if !depSet[path] {
				derr.missing = append(derr.missing, missingDep{f.filename, path})
			}
		}
	}
	if len(derr.missing) > 0 {
		return derr
	}
	return nil
}

type depsError struct {
	missing []missingDep
	known   []string
}

type missingDep struct {
	filename, imp string
}

var _ error = depsError{}

func (e depsError) Error() string {
	buf := bytes.NewBuffer(nil)
	fmt.Fprintf(buf, "missing strict dependencies:\n")
	for _, dep := range e.missing {
		fmt.Fprintf(buf, "\t%s: import of %q\n", dep.filename, dep.imp)
	}
	if len(e.known) == 0 {
		fmt.Fprintln(buf, "No dependencies were provided.")
	} else {
		fmt.Fprintln(buf, "Known dependencies are:")
		for _, imp := range e.known {
			fmt.Fprintf(buf, "\t%s\n", imp)
		}
	}
	fmt.Fprint(buf, "Check that imports in Go sources match importpath attributes in deps.")
	return buf.String()
}

func isRelative(path string) bool {
	return strings.HasPrefix(path, "./") || strings.HasPrefix(path, "../")
}
