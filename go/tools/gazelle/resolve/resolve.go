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
	"go/build"
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
	if build.IsLocalImport(imp) {
		cleanRel := path.Clean(path.Join(pkgRel, imp))
		if build.IsLocalImport(cleanRel) {
			return Label{}, fmt.Errorf("relative import path %q from %q points outside of repository", imp, pkgRel)
		}
		imp = path.Join(r.c.GoPrefix, cleanRel)
	}

	switch {
	case IsStandard(imp):
		return Label{}, fmt.Errorf("import path %q is in the standard library", imp)
	case imp == r.c.GoPrefix:
		return r.l.LibraryLabel(""), nil
	case r.c.GoPrefix == "" || strings.HasPrefix(imp, r.c.GoPrefix+"/"):
		return r.l.LibraryLabel(strings.TrimPrefix(imp, r.c.GoPrefix+"/")), nil
	default:
		return r.external.resolve(imp)
	}
}

const (
	wellKnownPrefix     = "google/protobuf/"
	wellKnownGoProtoPkg = "ptypes"
)

// ResolveProto resolves an import statement in a .proto file to a label
// for a proto_library rule.
func (r *Resolver) ResolveProto(imp string) (Label, error) {
	if !strings.HasSuffix(imp, ".proto") {
		return Label{}, fmt.Errorf("can't import non-proto: %q", imp)
	}
	imp = imp[:len(imp)-len(".proto")]

	if isWellKnown(imp) {
		// Well Known Type
		name := path.Base(imp) + "_proto"
		return Label{Repo: config.WellKnownTypesProtoRepo, Name: name}, nil
	}

	// Temporary hack: guess the label based on the proto file name. We assume
	// all proto files in a directory belong to the same package, and the
	// package name matches the directory base name.
	// TODO(#859): use dependency table to resolve once it exists.
	rel := path.Dir(imp)
	if rel == "." {
		rel = ""
	}
	name := relBaseName(r.c, rel)
	return r.l.ProtoLabel(rel, name), nil
}

// ResolveGoProto resolves an import statement in a .proto file to a
// label for a go_library rule that embeds the corresponding go_proto_library.
func (r *Resolver) ResolveGoProto(imp string) (Label, error) {
	if !strings.HasSuffix(imp, ".proto") {
		return Label{}, fmt.Errorf("can't import non-proto: %q", imp)
	}
	imp = imp[:len(imp)-len(".proto")]

	if isWellKnown(imp) {
		// Well Known Type
		pkg := path.Join(wellKnownGoProtoPkg, path.Base(imp))
		label := r.l.LibraryLabel(pkg)
		if r.c.GoPrefix != config.WellKnownTypesGoPrefix {
			label.Repo = config.WellKnownTypesGoProtoRepo
		}
		return label, nil
	}

	// Temporary hack: guess the label based on the proto file name. We assume
	// all proto files in a directory belong to the same package, and the
	// package name matches the directory base name.
	// TODO(#859): use dependency table to resolve once it exists.
	rel := path.Dir(imp)
	if rel == "." {
		rel = ""
	}
	return r.l.LibraryLabel(rel), nil
}

// IsStandard returns whether a package is in the standard library.
func IsStandard(imp string) bool {
	return stdPackages[imp]
}

func isWellKnown(imp string) bool {
	return strings.HasPrefix(imp, wellKnownPrefix) && strings.TrimPrefix(imp, wellKnownPrefix) == path.Base(imp)
}
