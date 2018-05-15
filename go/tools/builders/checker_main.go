/* Copyright 2018 The Bazel Authors. All rights reserved.

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

// Loads and runs registered analyses on a well-typed Go package.

package main

import (
	"errors"
	"flag"
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"go/types"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/analysis"
	"golang.org/x/tools/go/gcexportdata"
)

// run returns an error only if the package is successfully loaded and at least
// one analysis fails. All other errors (e.g. during loading) are logged but
// do not return an error so as not to unnecessarily interrupt builds.
func run(args []string) error {
	archiveFiles := multiFlag{}
	flags := flag.NewFlagSet("checker", flag.ContinueOnError)
	flags.Var(&archiveFiles, "archivefile", "Archive file of a direct dependency")
	stdlib := flags.String("stdlib", "", "Root directory of stdlib")
	if err := flags.Parse(args); err != nil {
		log.Println(err)
		return nil
	}
	if *stdlib == "" {
		log.Printf("missing stdlib root directory")
		return nil
	}
	importsToArchives := make(map[string]string)
	for _, a := range archiveFiles {
		kv := strings.Split(a, "=")
		if len(kv) != 2 {
			continue // sanity check
		}
		importsToArchives[kv[0]] = kv[1]
	}
	fset := token.NewFileSet()
	imp := &importer{
		fset:              fset,
		packages:          make(map[string]*types.Package),
		importsToArchives: importsToArchives,
		stdlib:            *stdlib,
	}
	apkg, err := load(fset, imp, flags.Args())
	if err != nil {
		log.Printf("error loading package: %v\n", err)
		return nil
	}

	c := make(chan result)
	for _, a := range analysis.Analyses() {
		go func(a *analysis.Analysis) {
			defer func() {
				// Prevent a panic in a single analysis from interrupting other analyses.
				if r := recover(); r != nil {
					c <- result{err: fmt.Errorf("recovered from panic during analysis %q: %v", a.Name, r)}
				}
			}()
			res, err := a.Run(apkg)
			if err != nil {
				if err != analysis.ErrSkipped {
					c <- result{err: fmt.Errorf("analysis failed: %v", err)}
				}
				c <- result{}
			}
			c <- result{findings: res.Findings}
		}(a)
	}
	var allFindings []*analysis.Finding
	for i := 0; i < len(analysis.Analyses()); i++ {
		result := <-c
		if result.err != nil {
			log.Println(result.err)
			continue
		}
		allFindings = append(allFindings, result.findings...)
	}
	if len(allFindings) != 0 {
		sort.Slice(allFindings, func(i, j int) bool {
			return allFindings[i].Pos < allFindings[j].Pos
		})
		errMsg := "errors found during build-time code analysis:\n"
		for _, f := range allFindings {
			errMsg += fmt.Sprintf("%s: %s\n", fset.Position(f.Pos), f.Message)
		}
		return errors.New(errMsg)
	}
	return nil
}

func main() {
	log.SetFlags(0) // no timestamp
	log.SetPrefix("GoChecker: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

type result struct {
	findings []*analysis.Finding
	err      error
}

// load parses and type checks the source code in each file in filenames.
// On failure, it reports errors to Error and returns (nil, nil, nil).
func load(fset *token.FileSet, imp types.Importer, filenames []string) (*analysis.Package, error) {
	if len(filenames) == 0 {
		return nil, errors.New("no filenames")
	}
	var files []*ast.File
	for _, file := range filenames {
		f, err := parser.ParseFile(fset, file, nil, parser.ParseComments)
		if err != nil {
			return nil, err
		}
		files = append(files, f)
	}

	config := types.Config{
		Importer: imp,
		Error: func(err error) {
			e := err.(types.Error)
			msg := fmt.Sprintf("%s", e.Msg)
			posn := e.Fset.Position(e.Pos)
			if posn.Filename != "" {
				msg = fmt.Sprintf("%s: %s", posn, msg)
			}
			fmt.Fprintln(os.Stderr, msg)
		},
	}
	info := &types.Info{
		Types:     make(map[ast.Expr]types.TypeAndValue),
		Uses:      make(map[*ast.Ident]types.Object),
		Defs:      make(map[*ast.Ident]types.Object),
		Implicits: make(map[ast.Node]types.Object),
	}
	pkg, err := config.Check(files[0].Name.Name, fset, files, info)
	if err != nil {
		// Errors were already reported through config.Error.
		return nil, nil
	}
	return &analysis.Package{Fset: fset, Files: files, Types: pkg, Info: info}, nil
}

type importer struct {
	fset     *token.FileSet
	packages map[string]*types.Package
	// importsToArchives maps import paths to the path to the archive file representing the
	// corresponding library.
	importsToArchives map[string]string
	// stdlib is the root directory containing standard library package archive files.
	stdlib string
}

func (i *importer) Import(path string) (*types.Package, error) {
	archive, ok := i.importsToArchives[path]
	if !ok {
		// stdlib package.
		ctxt := build.Default
		archive = filepath.Join(i.stdlib, "pkg", ctxt.GOOS+"_"+ctxt.GOARCH, path+".a")
	}
	// open file
	f, err := os.Open(archive)
	if err != nil {
		return nil, err
	}
	defer func() {
		f.Close()
		if err != nil {
			// add file name to error
			err = fmt.Errorf("reading export data: %s: %v", archive, err)
		}
	}()

	r, err := gcexportdata.NewReader(f)
	if err != nil {
		return nil, err
	}

	return gcexportdata.Read(r, i.fset, i.packages, path)
}
