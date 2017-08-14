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

package rules

import (
	"fmt"
	"log"
	"path"
	"path/filepath"
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/resolve"
)

// Generator generates Bazel build rules for Go build targets
type Generator interface {
	// Generate generates a syntax tree of a BUILD file for "pkg". The file
	// contains rules for each non-empty target in "pkg". It also contains
	// "load" statements necessary for the rule constructors. If this is the
	// top-level package in the repository, the file will contain a
	// "go_prefix" rule. This is a convenience method for the other methods
	// in this interface.
	Generate(pkg *packages.Package) *bf.File

	// GeneratePrefix generates a go_prefix rule. This should be in the
	// top-level build file for the repository.
	GeneratePrefix() bf.Expr

	// GenerateRules generates a list of rules for targets in "pkg".
	GenerateRules(pkg *packages.Package) []bf.Expr

	// GenerateLoad generates a load statement for the symbols referenced
	// in "stmts". Returns nil if rules is empty.
	GenerateLoad(stmts []bf.Expr) bf.Expr
}

// NewGenerator returns a new instance of Generator.
// "buildRel" is a slash-separated path to the directory containing the
// build file being generated, relative to the repository root.
// "oldFile" is the existing build file. May be nil.
func NewGenerator(c *config.Config, r resolve.Resolver, l resolve.Labeler, buildRel string, oldFile *bf.File) Generator {
	shouldSetVisibility := oldFile == nil || !hasDefaultVisibility(oldFile)
	return &generator{c: c, r: r, l: l, buildRel: buildRel, shouldSetVisibility: shouldSetVisibility}
}

type generator struct {
	c                   *config.Config
	r                   resolve.Resolver
	l                   resolve.Labeler
	buildRel            string
	shouldSetVisibility bool
}

func (g *generator) Generate(pkg *packages.Package) *bf.File {
	f := &bf.File{
		Path: filepath.Join(pkg.Dir, g.c.DefaultBuildFileName()),
	}
	f.Stmt = append(f.Stmt, nil) // reserve space for load
	if pkg.Rel == "" {
		f.Stmt = append(f.Stmt, g.GeneratePrefix())
	}
	f.Stmt = append(f.Stmt, g.GenerateRules(pkg)...)
	f.Stmt[0] = g.GenerateLoad(f.Stmt[1:])
	return f
}

func (g *generator) GeneratePrefix() bf.Expr {
	return newRule("go_prefix", []interface{}{g.c.GoPrefix}, nil)
}

func (g *generator) GenerateRules(pkg *packages.Package) []bf.Expr {
	var rules []bf.Expr
	library, r := g.generateLib(pkg)
	if r != nil {
		rules = append(rules, r)
	}

	if r := g.generateBin(pkg, library); r != nil {
		rules = append(rules, r)
	}

	if r := g.filegroup(pkg); r != nil {
		rules = append(rules, r)
	}

	if r := g.generateTest(pkg, library, false); r != nil {
		rules = append(rules, r)
	}

	if r := g.generateTest(pkg, "", true); r != nil {
		rules = append(rules, r)
	}

	return rules
}

func (g *generator) GenerateLoad(stmts []bf.Expr) bf.Expr {
	loadableKinds := []string{
		// keep sorted
		"go_binary",
		"go_library",
		"go_prefix",
		"go_test",
	}

	kinds := make(map[string]bool)
	for _, s := range stmts {
		if c, ok := s.(*bf.CallExpr); ok {
			r := bf.Rule{c}
			kinds[r.Kind()] = true
		}
	}
	args := make([]bf.Expr, 0, len(kinds)+1)
	args = append(args, &bf.StringExpr{Value: config.RulesGoDefBzlLabel})
	for _, k := range loadableKinds {
		if kinds[k] {
			args = append(args, &bf.StringExpr{Value: k})
		}
	}
	if len(args) == 1 {
		return nil
	}
	return &bf.CallExpr{
		X:            &bf.LiteralExpr{Token: "load"},
		List:         args,
		ForceCompact: true,
	}
}

func (g *generator) generateBin(pkg *packages.Package, library string) bf.Expr {
	if !pkg.IsCommand() || pkg.Binary.Sources.IsEmpty() && library == "" {
		return nil
	}
	name := g.l.BinaryLabel(pkg.Rel).Name
	visibility := checkInternalVisibility(pkg.Rel, "//visibility:public")
	attrs := g.commonAttrs(pkg.Rel, name, visibility, pkg.Binary)
	if library != "" {
		attrs = append(attrs, keyvalue{"library", ":" + library})
	}
	return newRule("go_binary", nil, attrs)
}

func (g *generator) generateLib(pkg *packages.Package) (string, bf.Expr) {
	if !pkg.Library.HasGo() {
		return "", nil
	}
	name := g.l.LibraryLabel(pkg.Rel).Name
	var visibility string
	if pkg.IsCommand() {
		// Libraries made for a go_binary should not be exposed to the public.
		visibility = "//visibility:private"
	} else {
		visibility = checkInternalVisibility(pkg.Rel, "//visibility:public")
	}

	attrs := g.commonAttrs(pkg.Rel, name, visibility, pkg.Library)
	if !pkg.IsCommand() && g.c.StructureMode == config.FlatMode {
		// TODO(jayconrod): add importpath attributes outside of flat mode after
		// we have verified it works correctly.
		attrs = append(attrs, keyvalue{"importpath", pkg.ImportPath(g.c.GoPrefix)})
	}

	rule := newRule("go_library", nil, attrs)
	return name, rule
}

// hasDefaultVisibility returns whether oldFile contains a "package" rule with
// a "default_visibility" attribute. Rules generated by Gazelle should not
// have their own visibility attributes if this is the case.
func hasDefaultVisibility(oldFile *bf.File) bool {
	for _, s := range oldFile.Stmt {
		c, ok := s.(*bf.CallExpr)
		if !ok {
			continue
		}
		r := bf.Rule{c}
		if r.Kind() == "package" && r.Attr("default_visibility") != nil {
			return true
		}
	}
	return false
}

// checkInternalVisibility overrides the given visibility if the package is
// internal.
func checkInternalVisibility(rel, visibility string) string {
	if i := strings.LastIndex(rel, "/internal/"); i >= 0 {
		visibility = fmt.Sprintf("//%s:__subpackages__", rel[:i])
	} else if strings.HasPrefix(rel, "internal/") {
		visibility = "//:__subpackages__"
	}
	return visibility
}

// filegroup is a small hack for directories with pre-generated .pb.go files
// and also source .proto files.  This creates a filegroup for the .proto in
// addition to the usual go_library for the .pb.go files.
func (g *generator) filegroup(pkg *packages.Package) bf.Expr {
	if !pkg.HasPbGo || len(pkg.Protos) == 0 {
		return nil
	}
	return newRule("filegroup", nil, []keyvalue{
		{key: "name", value: config.DefaultProtosName},
		{key: "srcs", value: pkg.Protos},
		{key: "visibility", value: []string{"//visibility:public"}},
	})
}

func (g *generator) generateTest(pkg *packages.Package, library string, isXTest bool) bf.Expr {
	target := pkg.Test
	if isXTest {
		target = pkg.XTest
	}
	if !target.HasGo() {
		return nil
	}
	name := g.l.TestLabel(pkg.Rel, isXTest).Name
	attrs := g.commonAttrs(pkg.Rel, name, "", target)
	if library != "" {
		attrs = append(attrs, keyvalue{"library", ":" + library})
	}
	if pkg.HasTestdata {
		glob := globvalue{patterns: []string{"testdata/**"}}
		attrs = append(attrs, keyvalue{"data", glob})
	}
	if g.c.StructureMode == config.FlatMode {
		attrs = append(attrs, keyvalue{"rundir", pkg.Rel})
	}
	return newRule("go_test", nil, attrs)
}

func (g *generator) commonAttrs(pkgRel, name, visibility string, target packages.Target) []keyvalue {
	attrs := []keyvalue{{"name", name}}
	if !target.Sources.IsEmpty() {
		attrs = append(attrs, keyvalue{"srcs", g.sources(target.Sources, pkgRel)})
	}
	if target.Cgo {
		attrs = append(attrs, keyvalue{"cgo", true})
	}
	if !target.CLinkOpts.IsEmpty() {
		attrs = append(attrs, keyvalue{"clinkopts", g.options(target.CLinkOpts, pkgRel)})
	}
	if !target.COpts.IsEmpty() {
		attrs = append(attrs, keyvalue{"copts", g.options(target.COpts, pkgRel)})
	}
	if g.shouldSetVisibility && visibility != "" {
		attrs = append(attrs, keyvalue{"visibility", []string{visibility}})
	}
	if !target.Imports.IsEmpty() {
		deps := g.dependencies(target.Imports, pkgRel)
		attrs = append(attrs, keyvalue{"deps", deps})
	}
	return attrs
}

// sources converts paths in "srcs" which are relative to the Go package
// directory ("pkgRel") into relative paths to the build file
// being generated ("g.buildRel").
func (g *generator) sources(srcs packages.PlatformStrings, pkgRel string) packages.PlatformStrings {
	if g.buildRel == pkgRel {
		return srcs
	}
	rel := g.buildPkgRel(pkgRel)
	srcs, _ = srcs.Map(func(s string) (string, error) {
		return path.Join(rel, s), nil
	})
	return srcs
}

// buildPkgRel returns the relative slash-separated path from the directory
// containing the build file (g.buildRel) to the Go package directory (pkgRel).
// pkgRel must start with g.buildRel.
func (g *generator) buildPkgRel(pkgRel string) string {
	if g.buildRel == pkgRel {
		return ""
	}
	if g.buildRel == "" {
		return pkgRel
	}
	rel := strings.TrimPrefix(pkgRel, g.buildRel+"/")
	if rel == pkgRel {
		log.Panicf("relative path to go package %s must start with relative path to Bazel package %s", pkgRel, g.buildRel)
	}
	return rel
}

// dependencies converts import paths in "imports" into Bazel labels.
func (g *generator) dependencies(imports packages.PlatformStrings, pkgRel string) packages.PlatformStrings {
	resolve := func(imp string) (string, error) {
		if strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "..") {
			imp = path.Clean(path.Join(g.c.GoPrefix, pkgRel, imp))
		}
		label, err := g.r.Resolve(imp)
		if err != nil {
			return "", fmt.Errorf("in dir %q, could not resolve import path %q: %v", pkgRel, imp, err)
		}
		label.Relative = label.Repo == "" && label.Pkg == g.buildRel
		return label.String(), nil
	}

	deps, errors := imports.Map(resolve)
	for _, err := range errors {
		log.Print(err)
	}
	deps.Clean()
	return deps
}

func (g *generator) options(opts packages.PlatformStrings, rel string) packages.PlatformStrings {
	// TODO(jayconrod): paths in options (for example, include directories) should
	// be interpreted relative to the Go package. If the Go package is different
	// than the Bazel package (as it may be in flat mode), these paths will not
	// be correct. We should adjust them here, but they are difficult to identify.
	return opts
}
