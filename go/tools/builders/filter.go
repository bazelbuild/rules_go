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
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"log"
	"path/filepath"
	"strconv"
	"strings"
)

type goMetadata struct {
	filename string
	matched  bool
	isCgo    bool
	pkg      string
	imports  []string
}

// readFiles collects metadata for a list of files.
func readFiles(bctx build.Context, inputs []string) ([]*goMetadata, error) {
	outputs := []*goMetadata{}
	for _, input := range inputs {
		if m, err := readGoMetadata(bctx, input, true); err != nil {
			return nil, err
		} else if m.matched {
			outputs = append(outputs, m)
		}
	}
	return outputs, nil
}

// filterFiles applies build constraints to a list of input files. It returns
// list of input files that should be compiled.
func filterFiles(bctx build.Context, inputs []string) ([]string, error) {
	var outputs []string
	for _, input := range inputs {
		if m, err := readGoMetadata(bctx, input, false); err != nil {
			return nil, err
		} else if m.matched {
			outputs = append(outputs, input)
		}
	}
	return outputs, nil
}

// readGoMetadata applies build constraints to an input file and returns whether
// it should be compiled.
func readGoMetadata(bctx build.Context, input string, needPackage bool) (*goMetadata, error) {
	m := &goMetadata{
		filename: input,
	}
	dir, base := filepath.Split(input)
	// First check tag filtering
	match, err := bctx.MatchFile(dir, base)
	if err != nil {
		return m, err
	}
	m.matched = match
	// if we don't need the package, and we are cgo, no need to parse the file
	if !needPackage && bctx.CgoEnabled {
		return m, nil
	}
	// if it's not a go file, there is no package or cgo
	if !strings.HasSuffix(input, ".go") {
		return m, nil
	}

	// read the file header
	fset := token.NewFileSet()
	parsed, err := parser.ParseFile(fset, input, nil, parser.ImportsOnly)
	if err != nil {
		return m, err
	}
	m.pkg = parsed.Name.String()

	for _, decl := range parsed.Decls {
		d, ok := decl.(*ast.GenDecl)
		if !ok {
			continue
		}
		for _, dspec := range d.Specs {
			spec, ok := dspec.(*ast.ImportSpec)
			if !ok {
				continue
			}
			imp, err := strconv.Unquote(spec.Path.Value)
			if err != nil {
				log.Panicf("%s: invalid string `%s`", input, spec.Path.Value)
			}
			if imp == "C" {
				m.isCgo = true
				break
			}
		}
	}
	// matched if cgo is enabled or the file is not cgo
	m.matched = match && (bctx.CgoEnabled || !m.isCgo)

	for _, i := range parsed.Imports {
		path, err := strconv.Unquote(i.Path.Value)
		if err != nil {
			return m, err
		}
		m.imports = append(m.imports, path)
	}

	return m, nil
}
