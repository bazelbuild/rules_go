package main

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
		for _, f := range pkg.GoFiles {
			pr.packagesByFile[f] = pkg
		}
	}
	return pr
}

func (pr *PackageRegistry) FromPkgID(pkgPath string) *FlatPackage {
	return pr.packagesByImportPath[pkgPath]
}

func (pr *PackageRegistry) FromPkgPath(pkgPath string) *FlatPackage {
	return pr.packagesByImportPath[pkgPath]
}

func (pr *PackageRegistry) FromFile(filePath string) *FlatPackage {
	return pr.packagesByFile[filePath]
}

func (pr *PackageRegistry) Remove(pkgs ...*FlatPackage) *PackageRegistry {
	for _, pkg := range pkgs {
		delete(pr.packagesByID, pkg.ID)
		delete(pr.packagesByImportPath, pkg.PkgPath)
		for _, f := range pkg.GoFiles {
			delete(pr.packagesByFile, f)
		}
	}
	return pr
}

func (pr *PackageRegistry) ToList() []*FlatPackage {
	pkgs := make([]*FlatPackage, 0, len(pr.packagesByID))
	for _, pkg := range pr.packagesByID {
		pkgs = append(pkgs, pkg)
	}
	return pkgs
}

func (pr *PackageRegistry) ResolvePaths(prf PathResolverFunc) error {
	for _, pkg := range pr.packagesByID {
		pkg.ResolvePaths(prf)
	}
	return nil
}

func (pr *PackageRegistry) ResolveImports() error {
	for _, pkg := range pr.packagesByID {
		pkg.ResolveImports(func(importPath string) *FlatPackage {
			return pr.FromPkgPath(importPath)
		})
	}
	return nil
}
