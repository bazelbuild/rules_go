// Copyright 2013 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found at
//
// https://github.com/golang/tools/blob/master/LICENSE

package main

import (
	"go/ast"
	"go/token"
	"strconv"
	"strings"
)

// Adapted from golang.org/x/tools/go/ast/astutil.AddNamedImport
func addNamedImport(fset *token.FileSet, f *ast.File, name, path string) bool {
	newImport := &ast.ImportSpec{
		Path: &ast.BasicLit{
			Kind:  token.STRING,
			Value: strconv.Quote(path),
		},
	}
	if name != "" {
		newImport.Name = &ast.Ident{Name: name}
	}

	// Find an import decl to add to.
	// The goal is to find an existing import
	// whose import path has the longest shared
	// prefix with path.
	var (
		bestMatch  = -1         // length of longest shared prefix
		lastImport = -1         // index in f.Decls of the file's final import decl
		impDecl    *ast.GenDecl // import decl containing the best match
		impIndex   = -1         // spec index in impDecl containing the best match

		isThirdPartyPath = isThirdParty(path)
	)
	for i, decl := range f.Decls {
		gen, ok := decl.(*ast.GenDecl)
		if ok && gen.Tok == token.IMPORT {
			lastImport = i
			// Do not add to import "C", to avoid disrupting the
			// association with its doc comment, breaking cgo.
			if declImports(gen, "C") {
				continue
			}

			// Match an empty import decl if that's all that is available.
			if len(gen.Specs) == 0 && bestMatch == -1 {
				impDecl = gen
			}

			// Compute longest shared prefix with imports in this group and find best
			// matched import spec.
			// 1. Always prefer import spec with longest shared prefix.
			// 2. While match length is 0,
			// - for stdlib package: prefer first import spec.
			// - for third party package: prefer first third party import spec.
			// We cannot use last import spec as best match for third party package
			// because grouped imports are usually placed last by goimports -local
			// flag.
			// See issue #19190.
			seenAnyThirdParty := false
			for j, spec := range gen.Specs {
				impspec := spec.(*ast.ImportSpec)
				p := importPath(impspec)
				n := matchLen(p, path)
				if n > bestMatch || (bestMatch == 0 && !seenAnyThirdParty && isThirdPartyPath) {
					bestMatch = n
					impDecl = gen
					impIndex = j
				}
				seenAnyThirdParty = seenAnyThirdParty || isThirdParty(p)
			}
		}
	}

	// If no import decl found, add one after the last import.
	if impDecl == nil {
		impDecl = &ast.GenDecl{
			Tok: token.IMPORT,
		}
		if lastImport >= 0 {
			impDecl.TokPos = f.Decls[lastImport].End()
		} else {
			// There are no existing imports.
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
		f.Decls = append(f.Decls, nil)
		copy(f.Decls[lastImport+2:], f.Decls[lastImport+1:])
		f.Decls[lastImport+1] = impDecl
	}

	// Insert new import at insertAt.
	insertAt := 0
	if impIndex >= 0 {
		// insert after the found import
		insertAt = impIndex + 1
	}
	impDecl.Specs = append(impDecl.Specs, nil)
	copy(impDecl.Specs[insertAt+1:], impDecl.Specs[insertAt:])
	impDecl.Specs[insertAt] = newImport
	pos := impDecl.Pos()
	if insertAt > 0 {
		// If there is a comment after an existing import, preserve the comment
		// position by adding the new import after the comment.
		if spec, ok := impDecl.Specs[insertAt-1].(*ast.ImportSpec); ok && spec.Comment != nil {
			pos = spec.Comment.End()
		} else {
			// Assign same position as the previous import,
			// so that the sorter sees it as being in the same block.
			pos = impDecl.Specs[insertAt-1].Pos()
		}
	}
	if newImport.Name != nil {
		newImport.Name.NamePos = pos
	}
	newImport.Path.ValuePos = pos
	newImport.EndPos = pos

	// Clean up parens. impDecl contains at least one spec.
	if len(impDecl.Specs) == 1 {
		// Remove unneeded parens.
		impDecl.Lparen = token.NoPos
	} else if !impDecl.Lparen.IsValid() {
		// impDecl needs parens added.
		impDecl.Lparen = impDecl.Specs[0].Pos()
	}

	f.Imports = append(f.Imports, newImport)

	if len(f.Decls) <= 1 {
		return true
	}

	// Merge all the import declarations into the first one.
	var first *ast.GenDecl
	for i := 0; i < len(f.Decls); i++ {
		decl := f.Decls[i]
		gen, ok := decl.(*ast.GenDecl)
		if !ok || gen.Tok != token.IMPORT || declImports(gen, "C") {
			continue
		}
		if first == nil {
			first = gen
			continue // Don't touch the first one.
		}
		// We now know there is more than one package in this import
		// declaration. Ensure that it ends up parenthesized.
		first.Lparen = first.Pos()
		// Move the imports of the other import declaration to the first one.
		for _, spec := range gen.Specs {
			spec.(*ast.ImportSpec).Path.ValuePos = first.Pos()
			first.Specs = append(first.Specs, spec)
		}
		f.Decls = append(f.Decls[:i], f.Decls[i+1:]...)
		i--
	}

	return true
}

// This function is copied from golang.org/x/tools/go/ast/astutil.isThirdParty
func isThirdParty(importPath string) bool {
	// Third party package import path usually contains "." (".com", ".org", ...)
	// This logic is taken from golang.org/x/tools/imports package.
	return strings.Contains(importPath, ".")
}

// importPath returns the unquoted import path of s,
// or "" if the path is not properly quoted.
// This function is copied from golang.org/x/tools/go/ast/astutil.importPath
func importPath(s *ast.ImportSpec) string {
	t, err := strconv.Unquote(s.Path.Value)
	if err != nil {
		return ""
	}
	return t
}

// declImports reports whether gen contains an import of path.
// This function is copied from golang.org/x/tools/go/ast/astutil.declImports
func declImports(gen *ast.GenDecl, path string) bool {
	if gen.Tok != token.IMPORT {
		return false
	}
	for _, spec := range gen.Specs {
		impspec := spec.(*ast.ImportSpec)
		if importPath(impspec) == path {
			return true
		}
	}
	return false
}

// matchLen returns the length of the longest path segment prefix shared by x and y.
// This function is copied from golang.org/x/tools/go/ast/astutil.matchLen
func matchLen(x, y string) int {
	n := 0
	for i := 0; i < len(x) && i < len(y) && x[i] == y[i]; i++ {
		if x[i] == '/' {
			n++
		}
	}
	return n
}
