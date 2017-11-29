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
	"io/ioutil"
	"log"
	"path/filepath"
	"strconv"
	"strings"
)

// filterFiles applies build constraints to a list of input files. It returns
// list of input files that should be compiled.
func filterFiles(bctx build.Context, inputs []string) ([]string, error) {
	var outputs []string
	for _, input := range inputs {
		if match, _, _, err := matchFile(bctx, input, false); err != nil {
			return nil, err
		} else if match {
			outputs = append(outputs, input)
		}
	}
	return outputs, nil
}

// matchFile applies build constraints to an input file and returns whether
// it should be compiled.
// TODO(#70): cross compilation: support GOOS, GOARCH that are different
// from the host platform.
func matchFile(bctx build.Context, input string, needPackage bool) (bool, bool, string, error) {
	dir, base := filepath.Split(input)
	// First check tag filtering
	match, err := bctx.MatchFile(dir, base)
	if err != nil {
		return false, false, "", err
	}
	// if we don't need the package, and we are cgo, no need to parse the file
	if !needPackage && bctx.CgoEnabled {
		return match, false, "", nil
	}
	// if it's not a go file, there is no package or cgo
	if !strings.HasSuffix(input, ".go") {
		return match, false, "", nil
	}
	data, err := ioutil.ReadFile(input)
	if err != nil {
		return false, false, "", err
	}
	isCgo, pkg, err := testCgo(input, data)
	if err != nil {
		return false, false, "", err
	}
	// match if cgo is enabled or the file is not cgo
	return match && (bctx.CgoEnabled || !isCgo), isCgo, pkg, err
}

func testCgo(src string, data []byte) (bool, string, error) {
	fset := token.NewFileSet()
	parsed, err := parser.ParseFile(fset, src, data, parser.ImportsOnly)
	if err != nil {
		return false, "", err
	}
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
				log.Panicf("%s: invalid string `%s`", src, spec.Path.Value)
			}
			if imp == "C" {
				return true, parsed.Name.String(), nil
			}
		}
	}
	return false, parsed.Name.String(), nil
}
