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
	"fmt"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"strconv"
)

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

// registerCoverage modifies coverSrcFilename, the output file from go tool cover.
// It adds a call to coverdata.RegisterCoverage, which ensures the coverage
// data from each file is reported. The name by which the file is registered
// need not match its original name (it may use the importpath).
func registerCoverage(coverSrcFilename, varName, srcName string) error {
	coverSrc, err := os.ReadFile(coverSrcFilename)
	if err != nil {
		return fmt.Errorf("instrumentForCoverage: reading instrumented source: %w", err)
	}

	// Parse the file.
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, coverSrcFilename, coverSrc, parser.ParseComments)
	if err != nil {
		return nil // parse error: proceed and let the compiler fail
	}

	// Perform edits using a byte buffer instead of the AST, because
	// we can not use go/format to write the AST back out without
	// changing line numbers.
	editor := NewBuffer(coverSrc)

	// Ensure coverdata is imported. Use an existing import if present
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
					editor.Replace(
						fset.Position(imp.Name.Pos()).Offset,
						fset.Position(imp.Name.End()).Offset,
						"coverdata")
					coverdataName = "coverdata"
				} else {
					coverdataName = imp.Name.Name
				}
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
		editor.Insert(fset.Position(f.Name.End()).Offset, fmt.Sprintf("; import %q", coverdataPath))
	}

	// Append an init function.
	var buf = bytes.NewBuffer(editor.Bytes())
	fmt.Fprintf(buf, `
func init() {
	%s.RegisterFile(%q,
		%[3]s.Count[:],
		%[3]s.Pos[:],
		%[3]s.NumStmt[:])
}
`, coverdataName, srcName, varName)
	if err := ioutil.WriteFile(coverSrcFilename, buf.Bytes(), 0666); err != nil {
		return fmt.Errorf("registerCoverage: %v", err)
	}
	return nil
}
