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
	"go/parser"
	"go/token"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

// A WalkFunc is a callback called by Walk for each package.
type WalkFunc func(pkg *build.Package) error

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
// the directory name, a *build.MultiplePackageError error is returned.
func Walk(bctx build.Context, root string, f WalkFunc) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return nil
		}
		if base := info.Name(); base == "" || base[0] == '.' || base[0] == '_' || base == "testdata" {
			return filepath.SkipDir
		}

		pkg, err := findPackage(bctx, path)
		if err != nil {
			if _, ok := err.(*build.NoGoError); ok {
				return nil
			}
			return err
		}
		return f(pkg)
	})
}

func findPackage(bctx build.Context, dir string) (*build.Package, error) {
	packageGoFiles, otherFiles, err := findPackageFiles(dir)
	if err != nil {
		return nil, err
	}

	packageName, err := selectPackageName(packageGoFiles, dir)
	if err != nil {
		return nil, err
	}

	var files []os.FileInfo
	files = append(files, packageGoFiles[packageName]...)
	files = append(files, otherFiles...)
	sort.Slice(files, func(i, j int) bool {
		return files[i].Name() < files[j].Name()
	})
	bctx.ReadDir = func(dir string) ([]os.FileInfo, error) {
		return files, nil
	}
	return bctx.ImportDir(dir, build.ImportComment)
}

func findPackageFiles(dir string) (packageGoFiles map[string][]os.FileInfo, otherFiles []os.FileInfo, err error) {
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		return
	}

	packageGoFiles = make(map[string][]os.FileInfo)
	for _, file := range files {
		if file.IsDir() {
			continue
		}

		name := file.Name()
		filename := filepath.Join(dir, name)
		ext := path.Ext(name)
		isGo := ext == ".go"

		if !isGo {
			otherFiles = append(otherFiles, file)
			continue
		}
		fset := token.NewFileSet()
		ast, err := parser.ParseFile(fset, filename, nil, parser.PackageClauseOnly)
		if err != nil {
			log.Printf("%s: error parsing package clause: %v", filename, err)
			continue
		}

		packageName := ast.Name.Name
		if packageName == "documentation" {
			// go/build ignores this package.
			continue
		}
		if strings.HasSuffix(packageName, "_test") {
			packageName = packageName[:len(packageName)-len("_test")]
		}
		packageGoFiles[packageName] = append(packageGoFiles[packageName], file)
	}
	return
}

func defaultPackageName(dir string) string {
	pname := filepath.Base(dir)
	if pname == "." || pname == "/" {
		// We'll only use this name at the root of the filesystem.
		return "unnamed"
	}
	return pname
}

func selectPackageName(packageGoFiles map[string][]os.FileInfo, dir string) (string, error) {
	if len(packageGoFiles) == 0 {
		return "", &build.NoGoError{Dir: dir}
	} else if len(packageGoFiles) == 1 {
		var packageName string
		for name, _ := range packageGoFiles {
			packageName = name
		}
		return packageName, nil
	} else {
		defaultName := defaultPackageName(dir)
		if _, ok := packageGoFiles[defaultName]; ok {
			return defaultName, nil
		}

		err := &build.MultiplePackageError{Dir: dir}
		for name, files := range packageGoFiles {
			// Add the first file for each package for the error message.
			// Error() method expects these lists to be the same length. File
			// lists are guaranteed to be non-empty.
			err.Packages = append(err.Packages, name)
			err.Files = append(err.Files, files[0].Name())
		}
		return "", err
	}
}
