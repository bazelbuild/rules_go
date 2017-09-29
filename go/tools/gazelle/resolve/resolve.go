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

package resolve

import (
	"fmt"
	"path"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// Resolver resolves import strings in source files (import paths in Go,
// import statements in protos) into Bazel labels.
// TODO(#859): imports are currently resolved by guessing a label based
// on the name. We should be smarter about this and build a table mapping
// import paths to labels that we can use to cross-reference.
type Resolver struct {
	c        *config.Config
	l        Labeler
	external nonlocalResolver
}

// nonlocalResolver resolves import paths outside of the current repository's
// prefix. Once we have smarter import path resolution, this shouldn't
// be necessary, and we can remove this abstraction.
type nonlocalResolver interface {
	resolve(imp string) (Label, error)
}

func NewResolver(c *config.Config, l Labeler) *Resolver {
	var e nonlocalResolver
	switch c.DepMode {
	case config.ExternalMode:
		e = newExternalResolver(l, c.KnownImports)
	case config.VendorMode:
		e = newVendoredResolver(l)
	}

	return &Resolver{
		c:        c,
		l:        l,
		external: e,
	}
}

// ResolveGo resolves an import path from a Go source file to a label.
// pkgRel is the path to the Go package relative to the repository root; it
// is used to resolve relative imports.
func (r *Resolver) ResolveGo(imp, pkgRel string) (Label, error) {
	if imp == "." || imp == ".." ||
		strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "../") {
		cleanRel := path.Clean(path.Join(pkgRel, imp))
		if strings.HasPrefix(cleanRel, "..") {
			return Label{}, fmt.Errorf("relative import path %q from %q points outside of repository", imp, pkgRel)
		}
		imp = path.Join(r.c.GoPrefix, cleanRel)
	}

	if imp != r.c.GoPrefix && !strings.HasPrefix(imp, r.c.GoPrefix+"/") {
		return r.external.resolve(imp)
	}

	if imp == r.c.GoPrefix {
		return r.l.LibraryLabel(""), nil
	}
	return r.l.LibraryLabel(strings.TrimPrefix(imp, r.c.GoPrefix+"/")), nil
}
