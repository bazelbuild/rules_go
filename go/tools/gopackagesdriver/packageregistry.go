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
