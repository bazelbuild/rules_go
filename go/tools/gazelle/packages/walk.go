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
	"os"
	"path/filepath"
)

// A WalkFunc is a callback called by Walk for each package.
type WalkFunc func(pkg *build.Package) error

// Walk walks through Go packages under the given dir.
// It calls back "f" for each package.
//
// It is similar to "golang.org/x/tools/go/buildutil".ForEachPackage, but
// it does not assume the standard Go tree because Bazel rules_go uses
// go_prefix instead of the standard tree.
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

		pkg, err := bctx.ImportDir(path, build.ImportComment)
		switch err.(type) {
		case *build.NoGoError:
			return nil
		case *build.MultiplePackageError:
			return f(pkg)
		default:
			return f(pkg)
		}
	})
}
