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
	"sort"
	"strings"

	bzl "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// A WalkFunc is a callback called by Walk for each package.
type WalkFunc func(pkg *Package, oldFile *bzl.File)

// Walk walks through directories under "root".
// It calls back "f" for each package. If an existing BUILD file is present
// in the directory, it will be parsed and passed to "f" as well.
//
// Walk is similar to "golang.org/x/tools/go/buildutil".ForEachPackage, but
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
	// visit walks the directory tree in post-order. It returns whether the
	// the directory it was called on or any subdirectory contains a Bazel
	// package. This affects whether "testdata" directories are considered
	// data dependencies.
	var visit func(string) bool
	visit = func(path string) bool {
		// Look for an existing BUILD file. Directives in this file may influence
		// the rest of the process.
		var oldFile *bzl.File
		haveError := false
		for _, base := range c.ValidBuildFileNames {
			oldPath := filepath.Join(path, base)
			st, err := os.Stat(oldPath)
			if os.IsNotExist(err) || err == nil && st.IsDir() {
				continue
			}
			oldData, err := ioutil.ReadFile(oldPath)
			if err != nil {
				log.Print(err)
				haveError = true
				continue
			}
			if oldFile != nil {
				log.Printf("in directory %s, multiple Bazel files are present: %s, %s",
					path, filepath.Base(oldFile.Path), base)
				haveError = true
				continue
			}
			oldFile, err = bzl.Parse(oldPath, oldData)
			if err != nil {
				log.Print(err)
				haveError = true
				continue
			}
		}

		var excluded map[string]bool
		if oldFile != nil {
			excluded = findExcludedFiles(oldFile)
		}

		// List files and subdirectories.
		files, err := ioutil.ReadDir(path)
		if err != nil {
			log.Print(err)
			return false
		}

		var goFiles, otherFiles, subdirs []string
		for _, f := range files {
			base := f.Name()
			switch {
			case base == "" || base[0] == '.' || base[0] == '_' || excluded != nil && excluded[base]:
				continue

			case f.IsDir():
				subdirs = append(subdirs, base)

			case strings.HasSuffix(base, ".go"):
				goFiles = append(goFiles, base)

			default:
				otherFiles = append(otherFiles, base)
			}
		}

		// Recurse into subdirectories.
		hasTestdata := false
		subdirHasPackage := false
		for _, sub := range subdirs {
			hasPackage := visit(filepath.Join(path, sub))
			if sub == "testdata" && !hasPackage {
				hasTestdata = true
			}
			subdirHasPackage = subdirHasPackage || hasPackage
		}

		hasPackage := subdirHasPackage || oldFile != nil
		if haveError {
			return hasPackage
		}

		// Build a package from files in this directory.
		var genGoFiles []string
		if oldFile != nil {
			genGoFiles = findGenGoFiles(oldFile, excluded)
		}
		pkg := buildPackage(c, path, oldFile, goFiles, genGoFiles, otherFiles, hasTestdata)
		if pkg != nil {
			f(pkg, oldFile)
			hasPackage = true
		}
		return hasPackage
	}

	visit(dir)
}

// buildPackage reads source files in a given directory and returns a Package
// containing information about those files and how to build them.
//
// If no buildable .go files are found in the directory, nil will be returned.
// If the directory contains multiple buildable packages, the package whose
// name matches the directory base name will be returned. If there is no such
// package or if an error occurs, an error will be logged, and nil will be
// returned.
func buildPackage(c *config.Config, dir string, oldFile *bzl.File, goFiles, genGoFiles, otherFiles []string, hasTestdata bool) *Package {
	rel, err := filepath.Rel(c.RepoRoot, dir)
	if err != nil {
		log.Print(err)
		return nil
	}
	rel = filepath.ToSlash(rel)
	if rel == "." {
		rel = ""
	}

	// Process the .go files first.
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
				Name:        info.packageName,
				Dir:         dir,
				Rel:         rel,
				HasTestdata: hasTestdata,
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

	// Process the generated .go files. Note that generated files may have the
	// same names as static files. Bazel will use the generated files, but we
	// will look at the content of static files, assuming they will be the same.
	for _, goFile := range genGoFiles {
		i := sort.SearchStrings(goFiles, goFile)
		if i < len(goFiles) && goFiles[i] == goFile {
			// Explicitly excluded or found a static file with the same name.
			continue
		}
		info := fileNameInfo(dir, goFile)
		err := pkg.addFile(c, info, false)
		if err != nil {
			log.Print(err)
		}
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
		// buildPackage for packages with .go files present.
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

func findGenGoFiles(f *bzl.File, excluded map[string]bool) []string {
	var strs []string
	for _, r := range f.Rules("") {
		for _, key := range []string{"out", "outs"} {
			switch e := r.Attr(key).(type) {
			case *bzl.StringExpr:
				strs = append(strs, e.Value)
			case *bzl.ListExpr:
				for _, elem := range e.List {
					if s, ok := elem.(*bzl.StringExpr); ok {
						strs = append(strs, s.Value)
					}
				}
			}
		}
	}

	var goFiles []string
	for _, s := range strs {
		if !excluded[s] && strings.HasSuffix(s, ".go") {
			goFiles = append(goFiles, s)
		}
	}
	return goFiles
}

const gazelleExclude = "# gazelle:exclude " // marker in a BUILD file to exclude source files.

func findExcludedFiles(f *bzl.File) map[string]bool {
	excluded := make(map[string]bool)
	for _, s := range f.Stmt {
		comments := append(s.Comment().Before, s.Comment().After...)
		for _, c := range comments {
			if strings.HasPrefix(c.Token, gazelleExclude) {
				f := strings.TrimSpace(c.Token[len(gazelleExclude):])
				excluded[f] = true
			}
		}
	}
	return excluded
}
