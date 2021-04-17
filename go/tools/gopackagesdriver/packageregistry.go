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

type PackageRegistry struct {
	packagesByImportPath map[string]*FlatPackage
}

func NewPackageRegistry(pkgs ...*FlatPackage) *PackageRegistry {
	pr := &PackageRegistry{
		packagesByImportPath: map[string]*FlatPackage{},
	}
	pr.Add(pkgs...)
	return pr
}

func (pr *PackageRegistry) Add(pkgs ...*FlatPackage) *PackageRegistry {
	for _, pkg := range pkgs {
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

func (pr *PackageRegistry) ToList() []*FlatPackage {
	pkgs := make([]*FlatPackage, 0, len(pr.packagesByImportPath))
	for _, pkg := range pr.packagesByImportPath {
		pkgs = append(pkgs, pkg)
	}
	return pkgs
}

func (pr *PackageRegistry) ResolvePaths(prf PathResolverFunc) error {
	for _, pkg := range pr.packagesByImportPath {
		pkg.ResolvePaths(prf)
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
