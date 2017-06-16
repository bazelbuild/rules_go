/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package packages

import (
	"go/build"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// A WalkFunc is a callback called by Walk for each package.
type WalkFunc func(pkg *Package)

// Walk walks through directories under "root".
// It calls back "f" for each package.
//
// It is similar to "golang.org/x/tools/go/buildutil".ForEachPackage, but
// it does not assume the standard Go tree because Bazel rules_go uses
// go_prefix instead of the standard tree.
//
// If a directory contains no buildable Go code, "f" is not called. If a
// directory contains one package with any name, "f" will be called with that
// package. If a directory contains multiple packages and one of the package
// names matches the directory name, "f" will be called on that package and the
// other packages will be silently ignored. If none of the package names match
// the directory name, or if some other error occurs, an error will be logged,
// and "f" will not be called.
func Walk(c *config.Config, dir string, f WalkFunc) {
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return nil
		}
		if base := info.Name(); base == "" || base[0] == '.' || base == "testdata" {
			return filepath.SkipDir
		}

		if pkg := FindPackage(c, path); pkg != nil {
			f(pkg)
		}
		return nil
	})
	if err != nil {
		log.Print(err)
	}
}

// FindPackage reads source files in a given directory and returns a Package
// containing information about those files and how to build them.
//
// If no buildable .go files are found in the directory, nil will be returned.
// If the directory contains multiple buildable packages, the package whose
// name matches the directory base name will be returned. If there is no such
// package or if an error occurs, an error will be logged, and nil will be
// returned.
func FindPackage(c *config.Config, dir string) *Package {
	var goFiles, otherFiles []string

	// List the files in the directory and split into .go files and other files.
	// We need to process the Go files first to determine which package we'll
	// generate rules for if there are multiple packages.
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		log.Print(err)
		return nil
	}
	for _, file := range files {
		if file.IsDir() {
			continue
		}

		name := file.Name()
		if name == "" || name[0] == '.' || name[0] == '_' {
			continue
		}

		if strings.HasSuffix(name, ".go") {
			goFiles = append(goFiles, name)
		} else {
			otherFiles = append(otherFiles, name)
		}
	}

	// Process the .go files.
	packageMap := make(map[string]*Package)
	cgo := false
	for _, goFile := range goFiles {
		info, err := goFileInfo(c, dir, goFile)
		if err != nil {
			log.Print(err)
			continue
		}
		if info.packageName == "documentation" {
			// go/build ignores this package
			continue
		}

		cgo = cgo || info.isCgo

		if _, ok := packageMap[info.packageName]; !ok {
			packageMap[info.packageName] = &Package{
				Name: info.packageName,
				Dir:  dir,
			}
		}
		err = packageMap[info.packageName].addFile(c, info, false)
		if err != nil {
			log.Print(err)
		}
	}

	// Select a package to generate rules for.
	pkg, err := selectPackage(c, dir, packageMap)
	if err != nil {
		if _, ok := err.(*build.NoGoError); !ok {
			log.Print(err)
		}
		return nil
	}

	// Process the other files.
	for _, file := range otherFiles {
		info, err := otherFileInfo(dir, file)
		if err != nil {
			log.Print(err)
			continue
		}
		err = pkg.addFile(c, info, cgo)
		if err != nil {
			log.Print(err)
		}
	}

	return pkg
}

func selectPackage(c *config.Config, dir string, packageMap map[string]*Package) (*Package, error) {
	packagesWithGo := make(map[string]*Package)
	for name, pkg := range packageMap {
		if pkg.HasGo() {
			packagesWithGo[name] = pkg
		}
	}

	if len(packagesWithGo) == 0 {
		return nil, &build.NoGoError{Dir: dir}
	}

	if len(packagesWithGo) == 1 {
		for _, pkg := range packagesWithGo {
			return pkg, nil
		}
	}

	if pkg, ok := packagesWithGo[defaultPackageName(c, dir)]; ok {
		return pkg, nil
	}

	err := &build.MultiplePackageError{Dir: dir}
	for name, pkg := range packagesWithGo {
		// Add the first file for each package for the error message.
		// Error() method expects these lists to be the same length. File
		// lists must be non-empty. These lists are only created by
		// findPackageFiles for packages with .go files present.
		err.Packages = append(err.Packages, name)
		err.Files = append(err.Files, pkg.firstGoFile())
	}
	return nil, err
}

func defaultPackageName(c *config.Config, dir string) string {
	if dir != c.RepoRoot {
		return filepath.Base(dir)
	}
	name := path.Base(c.GoPrefix)
	if name == "." || name == "/" {
		// This can happen if go_prefix is empty or is all slashes.
		return "unnamed"
	}
	return name
}
