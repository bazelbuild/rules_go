// Copyright 2021 The Bazel Authors. All rights reserved.
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
	"strings"
)

type PackageRegistry struct {
	packagesByID         map[string]*FlatPackage
	packagesByImportPath map[string]*FlatPackage
	packagesByFile       map[string]*FlatPackage
}

func NewPackageRegistry(pkgs ...*FlatPackage) *PackageRegistry {
	pr := &PackageRegistry{
		packagesByID:         map[string]*FlatPackage{},
		packagesByImportPath: map[string]*FlatPackage{},
		packagesByFile:       map[string]*FlatPackage{},
	}
	pr.Add(pkgs...)
	return pr
}

func (pr *PackageRegistry) Add(pkgs ...*FlatPackage) *PackageRegistry {
	for _, pkg := range pkgs {
		pr.packagesByID[pkg.ID] = pkg
		pr.packagesByImportPath[pkg.PkgPath] = pkg
	}
	return pr
}

func (pr *PackageRegistry) FromPkgPath(pkgPath string) *FlatPackage {
	return pr.packagesByImportPath[pkgPath]
}

func (pr *PackageRegistry) Remove(pkgs ...*FlatPackage) *PackageRegistry {
	for _, pkg := range pkgs {
		delete(pr.packagesByImportPath, pkg.PkgPath)
	}
	return pr
}

func (pr *PackageRegistry) ResolvePaths(prf PathResolverFunc) error {
	for _, pkg := range pr.packagesByImportPath {
		pkg.ResolvePaths(prf)
		for _, f := range pkg.CompiledGoFiles {
			pr.packagesByFile[f] = pkg
		}
	}
	return nil
}

func (pr *PackageRegistry) ResolveImports() error {
	for _, pkg := range pr.packagesByImportPath {
		pkg.ResolveImports(func(importPath string) *FlatPackage {
			return pr.FromPkgPath(importPath)
		})
	}
	return nil
}

func (pr *PackageRegistry) walk(acc map[string]*FlatPackage, root string) {
	pkg := pr.packagesByID[root]
	acc[pkg.ID] = pkg
	for _, pkgID := range pkg.Imports {
		if _, ok := acc[pkgID]; !ok {
			pr.walk(acc, pkgID)
		}
	}
}

func (pr *PackageRegistry) Match(patterns ...string) ([]string, []*FlatPackage) {
	roots := map[string]struct{}{}
	wildcard := false

	for _, pattern := range patterns {
		if strings.HasPrefix(pattern, "file=") {
			f := strings.TrimPrefix(pattern, "file=")
			if pkg, ok := pr.packagesByFile[f]; ok {
				roots[pkg.ID] = struct{}{}
			}
		} else if pattern == "." || pattern == "./..." {
			wildcard = true
		} else {
			if pkg, ok := pr.packagesByImportPath[pattern]; ok {
				roots[pkg.ID] = struct{}{}
			}
		}
	}

	if wildcard {
		retPkgs := make([]*FlatPackage, 0, len(pr.packagesByImportPath))
		retRoots := make([]string, 0, len(pr.packagesByImportPath))
		for _, pkg := range pr.packagesByImportPath {
			if strings.HasPrefix(pkg.ID, "//") {
				retRoots = append(retRoots, pkg.ID)
				roots[pkg.ID] = struct{}{}
			}
			retPkgs = append(retPkgs, pkg)
		}
		return retRoots, retPkgs
	}

	walkedPackages := map[string]*FlatPackage{}
	retRoots := make([]string, 0, len(roots))
	for rootPkg := range roots {
		retRoots = append(retRoots, rootPkg)
		pr.walk(walkedPackages, rootPkg)
	}

	retPkgs := make([]*FlatPackage, 0, len(walkedPackages))
	for _, pkg := range walkedPackages {
		retPkgs = append(retPkgs, pkg)
	}

	return retRoots, retPkgs
}
