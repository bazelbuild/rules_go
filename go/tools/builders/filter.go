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
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"log"
	"path/filepath"
	"strconv"
	"strings"
)

type fileInfo struct {
	filename string
	ext      ext
	matched  bool
	isCgo    bool
	pkg      string
	imports  []string
}

type ext int

const (
	goExt ext = iota
	cExt
	cxxExt
	objcExt
	objcxxExt
	sExt
	hExt
)

type archiveSrcs struct {
	goSrcs, cSrcs, cxxSrcs, objcSrcs, objcxxSrcs, sSrcs, hSrcs []fileInfo
}

// filterAndSplitFiles filters files using build constraints and collates
// them by extension.
func filterAndSplitFiles(fileNames []string) (archiveSrcs, error) {
	var res archiveSrcs
	for _, s := range fileNames {
		src, err := readFileInfo(build.Default, s, true)
		if err != nil {
			return archiveSrcs{}, err
		}
		if !src.matched {
			continue
		}
		var srcs *[]fileInfo
		switch src.ext {
		case goExt:
			srcs = &res.goSrcs
		case cExt:
			srcs = &res.cSrcs
		case cxxExt:
			srcs = &res.cxxSrcs
		case objcExt:
			srcs = &res.objcSrcs
		case objcxxExt:
			srcs = &res.objcxxSrcs
		case sExt:
			srcs = &res.sSrcs
		case hExt:
			srcs = &res.hSrcs
		}
		*srcs = append(*srcs, src)
	}
	return res, nil
}

// readFileInfo applies build constraints to an input file and returns whether
// it should be compiled.
func readFileInfo(bctx build.Context, input string, needPackage bool) (fileInfo, error) {
	fi := fileInfo{filename: input}
	if ext := filepath.Ext(input); ext == ".C" {
		fi.ext = cxxExt
	} else {
		switch strings.ToLower(ext) {
		case ".go":
			fi.ext = goExt
		case ".c":
			fi.ext = cExt
		case ".cc", ".cxx", ".cpp":
			fi.ext = cxxExt
		case ".m":
			fi.ext = objcExt
		case ".mm":
			fi.ext = objcxxExt
		case ".s":
			fi.ext = sExt
		case ".h", ".hh", ".hpp", ".hxx":
			fi.ext = hExt
		default:
			return fileInfo{}, fmt.Errorf("unrecognized file extension: %s", ext)
		}
	}

	dir, base := filepath.Split(input)
	// Check build constraints on non-cgo files.
	// Skip cgo files, since they get rejected (due to leading '_') and won't
	// have any build constraints anyway.
	if strings.HasPrefix(base, "_cgo") {
		fi.matched = true
	} else {
		match, err := bctx.MatchFile(dir, base)
		if err != nil {
			return fi, err
		}
		fi.matched = match
	}
	// if we don't need the package, and we are cgo, no need to parse the file
	if !needPackage && bctx.CgoEnabled {
		return fi, nil
	}
	// if it's not a go file, there is no package or cgo
	if !strings.HasSuffix(input, ".go") {
		return fi, nil
	}

	// read the file header
	fset := token.NewFileSet()
	parsed, err := parser.ParseFile(fset, input, nil, parser.ImportsOnly)
	if err != nil {
		return fi, err
	}
	fi.pkg = parsed.Name.String()

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
				fi.isCgo = true
				break
			}
		}
	}
	// matched if cgo is enabled or the file is not cgo
	fi.matched = fi.matched && (bctx.CgoEnabled || !fi.isCgo)

	for _, i := range parsed.Imports {
		path, err := strconv.Unquote(i.Path.Value)
		if err != nil {
			return fi, err
		}
		fi.imports = append(fi.imports, path)
	}

	return fi, nil
}
