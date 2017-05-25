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
	"fmt"
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
func Walk(bctx build.Context, repoRoot, goPrefix, dir string, f WalkFunc) error {
	return filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return nil
		}
		if base := info.Name(); base == "" || base[0] == '.' || base == "testdata" {
			return filepath.SkipDir
		}

		pr := packageReader{
			bctx:     bctx,
			repoRoot: repoRoot,
			goPrefix: goPrefix,
			dir:      path,
		}

		pkg, err := pr.findPackage()
		if err != nil {
			if _, ok := err.(*build.NoGoError); ok {
				return nil
			}
			return err
		}
		return f(pkg)
	})
}

// packageReader reads package metadata from a directory.
type packageReader struct {
	bctx                    build.Context
	repoRoot, goPrefix, dir string
	warnHook                func(error)
}

func (pr *packageReader) findPackage() (*build.Package, error) {
	packageGoFiles, otherFiles, err := pr.findPackageFiles()
	if err != nil {
		return nil, err
	}

	packageName, err := pr.selectPackageName(packageGoFiles)
	if err != nil {
		return nil, err
	}

	var files []os.FileInfo
	files = append(files, packageGoFiles[packageName]...)
	files = append(files, otherFiles...)
	sort.Sort(byName(files))
	pr.bctx.ReadDir = func(dir string) ([]os.FileInfo, error) {
		return files, nil
	}
	return pr.bctx.ImportDir(pr.dir, build.ImportComment)
}

func (pr *packageReader) findPackageFiles() (packageGoFiles map[string][]os.FileInfo, otherFiles []os.FileInfo, err error) {
	files, err := ioutil.ReadDir(pr.dir)
	if err != nil {
		return nil, nil, err
	}

	packageGoFiles = make(map[string][]os.FileInfo)
	for _, file := range files {
		if file.IsDir() {
			continue
		}

		name := file.Name()
		filename := filepath.Join(pr.dir, name)
		ext := path.Ext(name)
		isGo := ext == ".go"

		if !isGo {
			otherFiles = append(otherFiles, file)
			continue
		}
		fset := token.NewFileSet()
		ast, err := parser.ParseFile(fset, filename, nil, parser.PackageClauseOnly)
		if err != nil {
			pr.warn(fmt.Errorf("%s: error parsing package clause: %v", filename, err))
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
	return packageGoFiles, otherFiles, nil
}

func (pr *packageReader) defaultPackageName() string {
	if pr.dir != pr.repoRoot {
		return filepath.Base(pr.dir)
	}
	name := path.Base(pr.goPrefix)
	if name == "." || name == "/" {
		// This can happen if go_prefix is empty or is all slashes.
		return "unnamed"
	}
	return name
}

func (pr *packageReader) selectPackageName(packageGoFiles map[string][]os.FileInfo) (string, error) {
	if len(packageGoFiles) == 0 {
		return "", &build.NoGoError{Dir: pr.dir}
	}

	if len(packageGoFiles) == 1 {
		var packageName string
		for name, _ := range packageGoFiles {
			packageName = name
		}
		return packageName, nil
	}

	defaultName := pr.defaultPackageName()
	if _, ok := packageGoFiles[defaultName]; ok {
		return defaultName, nil
	}

	err := &build.MultiplePackageError{Dir: pr.dir}
	for name, files := range packageGoFiles {
		// Add the first file for each package for the error message.
		// Error() method expects these lists to be the same length. File
		// lists must be non-empty. These lists are only created by
		// findPackageFiles for packages with .go files present.
		err.Packages = append(err.Packages, name)
		err.Files = append(err.Files, files[0].Name())
	}
	return "", err
}

func (pr *packageReader) warn(err error) {
	if pr.warnHook != nil {
		pr.warnHook(err)
		return
	}
	log.Println(err)
}

type byName []os.FileInfo

var _ sort.Interface = byName{}

func (s byName) Len() int {
	return len(s)
}

func (s byName) Less(i, j int) bool {
	return s[i].Name() < s[j].Name()
}

func (s byName) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}
