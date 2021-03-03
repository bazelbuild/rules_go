// Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
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

package pkgconv

import (
	"fmt"
	"go/parser"
	"go/token"
	"log"
	"path/filepath"
	"strings"

	"golang.org/x/tools/go/packages"
)

func testmainPath(t target) string {
	parts := strings.SplitN(t.name, ":", 2)
	dir := binpath(parts[0])
	return filepath.Join(dir, fmt.Sprintf("%s_/testmain.go", parts[1]))
}

func convertGoTest(t target, targets map[string]*target) []*packages.Package {
	importPath := t.importpath
	var packageName string

	extPackages := make(map[string]*packages.Package)

	embed := packages.Package{
		Imports: make(map[string]*packages.Package),
	}

	// First process embedded sources
	for _, e := range t.embed {
		if et := targets[e]; et != nil {
			if epkg := et.toPackage(targets); epkg != nil {
				embed.GoFiles = append(embed.GoFiles, epkg[0].GoFiles...)
				embed.OtherFiles = append(embed.OtherFiles, epkg[0].OtherFiles...)
				if importPath == "" {
					importPath = epkg[0].PkgPath
				}
				for k, v := range epkg[0].Imports {
					if embed.Imports[k] == nil && v != nil {
						embed.Imports[k] = v
					}
				}
				for _, s := range epkg[0].GoFiles {
					if packageName == "" {
						packageName = parsePackageName(s)
					} else {
						break
					}
				}
			}
		} else {
			log.Printf("Unknown embed %v\n", e)
		}
	}

	pkg := &packages.Package{
		ID:      t.name,
		PkgPath: fmt.Sprintf("%v.test", importPath),
		Imports: make(map[string]*packages.Package),
	}

	processGoSrcs(t, targets, pkg)
	processDeps(t, targets, pkg)

	embed.ID = fmt.Sprintf("%s [%s]", importPath, t.name)
	embed.PkgPath = embed.ID
	for k, v := range pkg.Imports {
		if v != nil {
			embed.Imports[k] = v
		}
	}

	// separate internal and external test files
	for _, f := range pkg.GoFiles {
		name := parsePackageName(f)
		if name == packageName || name == "" {
			embed.GoFiles = append(embed.GoFiles, f)
		} else {
			extPkg, ok := extPackages[name]
			if !ok {
				extImportPath := filepath.Join(filepath.Dir(importPath), name)
				extPkg = &packages.Package{
					ID:      fmt.Sprintf("%s [%s]", extImportPath, t.name),
					PkgPath: extImportPath,
					Imports: pkg.Imports,
				}
				extPackages[name] = extPkg
			}
			extPkg.GoFiles = append(extPkg.GoFiles, f)
		}
	}
	pkg.Name = "main"
	pkg.GoFiles = []string{testmainPath(t)}
	pkg.Imports = make(map[string]*packages.Package, len(extPackages)+1)

	pkgs := make([]*packages.Package, 0, len(extPackages)+2)
	if len(embed.GoFiles) > 0 {
		pkgs = append(pkgs, &embed)
		pkg.Imports[importPath] = &packages.Package{ID: embed.ID}
	}
	for _, p := range extPackages {
		pkgs = append(pkgs, p)
		pkg.Imports[p.PkgPath] = &packages.Package{ID: p.ID}
	}
	pkgs = append(pkgs, pkg)

	return pkgs
}

func parsePackageName(filename string) string {
	fset := token.NewFileSet()
	if f, err := parser.ParseFile(fset, filename, nil, parser.PackageClauseOnly); err == nil {
		return f.Name.Name
	}
	return ""
}
