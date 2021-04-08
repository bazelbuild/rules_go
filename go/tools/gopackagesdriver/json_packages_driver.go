package main

import "fmt"

type JSONPackagesDriver struct {
	registry *PackageRegistry
}

func NewJSONPackagesDriver(jsonFiles []string, prf PathResolverFunc) (*JSONPackagesDriver, error) {
	jpd := &JSONPackagesDriver{
		registry: NewPackageRegistry(),
	}

	for _, f := range jsonFiles {
		if err := WalkFlatPackagesFromJSON(f, func(pkg *FlatPackage) {
			jpd.registry.Add(pkg)
		}); err != nil {
			return nil, fmt.Errorf("unable to walk json: %w", err)
		}
	}

	if err := jpd.registry.ResolvePaths(prf); err != nil {
		return nil, fmt.Errorf("unable to resolve paths: %w", err)
	}

	if err := jpd.registry.ResolveImports(); err != nil {
		return nil, fmt.Errorf("unable to resolve paths: %w", err)
	}

	return jpd, nil
}

func (b *JSONPackagesDriver) Packages() []*FlatPackage {
	return b.registry.ToList()
}
