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
	"bytes"
	"flag"
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"io/ioutil"
	"strconv"
)

// cover transforms a source file with "go tool cover". It is invoked by the
// Go rules as an action.
func cover(args []string) error {
	args, err := readParamsFiles(args)
	if err != nil {
		return err
	}
	flags := flag.NewFlagSet("cover", flag.ExitOnError)
	var coverSrc, coverVar, origSrc, srcName, mode string
	flags.StringVar(&coverSrc, "o", "", "coverage output file")
	flags.StringVar(&coverVar, "var", "", "name of cover variable")
	flags.StringVar(&origSrc, "src", "", "original source file")
	flags.StringVar(&srcName, "srcname", "", "source name printed in coverage data")
	flags.StringVar(&mode, "mode", "set", "coverage mode to use")
	goenv := envFlags(flags)
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	if coverSrc == "" {
		return fmt.Errorf("-o was not set")
	}
	if coverVar == "" {
		return fmt.Errorf("-var was not set")
	}
	if origSrc == "" {
		return fmt.Errorf("-src was not set")
	}
	if srcName == "" {
		srcName = origSrc
	}

	return instrumentForCoverage(goenv, origSrc, srcName, coverVar, mode, coverSrc)
}

// instrumentForCoverage runs "go tool cover" on a source file to produce
// a coverage-instrumented version of the file. It also registers the file
// with the coverdata package.
func instrumentForCoverage(goenv *env, srcPath, srcName, coverVar, mode, outPath string) error {
	goargs := goenv.goTool("cover", "-var", coverVar, "-mode", mode, "-o", outPath, srcPath)
	if err := goenv.runCommand(goargs); err != nil {
		return err
	}

	return registerCoverage(outPath, coverVar, srcName)
}

// registerCoverage modifies coverSrc, the output file from go tool cover. It
// adds a call to coverdata.RegisterCoverage, which ensures the coverage
// data from each file is reported. The name by which the file is registered
// need not match its original name (it may use the importpath).
func registerCoverage(coverSrc, varName, srcName string) error {
	// Parse the file.
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, coverSrc, nil, parser.ParseComments)
	if err != nil {
		return nil // parse error: proceed and let the compiler fail
	}

	// Ensure coverdata is imported in the AST. Use an existing import if present
	// or add a new one.
	const coverdataPath = "github.com/bazelbuild/rules_go/go/tools/coverdata"
	var coverdataName string
	for _, imp := range f.Imports {
		path, err := strconv.Unquote(imp.Path.Value)
		if err != nil {
			return nil // parse error: proceed and let the compiler fail
		}
		if path == coverdataPath {
			if imp.Name != nil {
				// renaming import
				if imp.Name.Name == "_" {
					// Change blank import to named import
					imp.Name.Name = "coverdata"
				}
				coverdataName = imp.Name.Name
			} else {
				// default import
				coverdataName = "coverdata"
			}
			break
		}
	}
	if coverdataName == "" {
		// No existing import. Add a new one.
		coverdataName = "coverdata"
		addNamedImport(fset, f, coverdataName, coverdataPath)
	}
	var buf bytes.Buffer
	if err := format.Node(&buf, fset, f); err != nil {
		return fmt.Errorf("registerCoverage: could not reformat coverage source %s: %v", coverSrc, err)
	}

	// Append an init function.
	fmt.Fprintf(&buf, `
func init() {
	%s.RegisterFile(%q,
		%[3]s.Count[:],
		%[3]s.Pos[:],
		%[3]s.NumStmt[:])
}
`, coverdataName, srcName, varName)
	if err := ioutil.WriteFile(coverSrc, buf.Bytes(), 0666); err != nil {
		return fmt.Errorf("registerCoverage: %v", err)
	}

	return nil
}

func addNamedImport(fset *token.FileSet, f *ast.File, name, path string) {
	imp := &ast.ImportSpec{
		Name: &ast.Ident{Name: name},
		Path: &ast.BasicLit{
			Kind:  token.STRING,
			Value: strconv.Quote(path),
		},
	}
	impDecl := &ast.GenDecl{Tok: token.IMPORT, Specs: []ast.Spec{imp}}
	f.Decls = append([]ast.Decl{impDecl}, f.Decls...)

	// Our new import, preceded by a blank line,  goes after the package declaration
	// and after the comment, if any, that starts on the same line as the
	// package declaration.
	impDecl.TokPos = f.Package
	file := fset.File(f.Package)
	pkgLine := file.Line(f.Package)
	for _, c := range f.Comments {
		if file.Line(c.Pos()) > pkgLine {
			break
		}
		// +2 for a blank line
		impDecl.TokPos = c.End() + 2
	}
}
