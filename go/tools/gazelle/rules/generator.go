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
	"os"
	"path/filepath"
	"strings"

	bzl "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
)

const (
	// defaultLibName is the name of the default go_library rule in a Go
	// package directory. It must be consistent to DEFAULT_LIB in go/private/common.bzl.
	defaultLibName = "go_default_library"
	// defaultTestName is a name of an internal test corresponding to
	// defaultLibName. It does not need to be consistent to something but it
	// just needs to be unique in the Bazel package
	defaultTestName = "go_default_test"
	// defaultXTestName is a name of an external test corresponding to
	// defaultLibName.
	defaultXTestName = "go_default_xtest"
	// defaultProtosName is the name of a filegroup created
	// whenever the library contains .pb.go files
	defaultProtosName = "go_default_library_protos"
	// defaultCgoLibName is the name of the default cgo_library rule in a Go package directory.
	defaultCgoLibName = "cgo_default_library"
)

// Generator generates Bazel build rules for Go build targets
type Generator interface {
	// Generate generates build rules for build targets in a Go package in a
	// repository.
	//
	// "rel" is a relative slash-separated path from the repostiry root
	// directory to the Go package directory. It is empty if the package
	// directory is the repository root itself.
	// "pkg" is a description about the package.
	Generate(rel string, pkg *packages.Package) []*bzl.Rule
}

func NewGenerator(c *config.Config) Generator {
	var (
		// TODO(yugui) Support another resolver to cover the pattern 2 in
		// https://github.com/bazelbuild/rules_go/issues/16#issuecomment-216010843
		r = structuredResolver{goPrefix: c.GoPrefix}
	)

	var e labelResolver
	switch c.DepMode {
	case config.ExternalMode:
		e = externalResolver{}
	case config.VendorMode:
		e = vendoredResolver{}
	default:
		return nil
	}

	return &generator{
		c: c,
		r: resolverFunc(func(importpath, dir string) (label, error) {
			if importpath != c.GoPrefix && !strings.HasPrefix(importpath, c.GoPrefix+"/") && !isRelative(importpath) {
				return e.resolve(importpath, dir)
			}
			return r.resolve(importpath, dir)
		}),
	}
}

type generator struct {
	c *config.Config
	r labelResolver
}

func (g *generator) Generate(rel string, pkg *packages.Package) []*bzl.Rule {
	var rules []*bzl.Rule
	if rel == "" {
		rules = append(rules, newRule("go_prefix", []interface{}{g.c.GoPrefix}, nil))
	}

	cgoLibrary, r := g.generateCgoLib(rel, pkg)
	if r != nil {
		rules = append(rules, r)
	}

	library, r := g.generateLib(rel, pkg, cgoLibrary)
	if r != nil {
		rules = append(rules, r)
	}

	if r := g.generateBin(rel, pkg, library); r != nil {
		rules = append(rules, r)
	}

	if r := g.filegroup(rel, pkg); r != nil {
		rules = append(rules, r)
	}

	testdataPath := filepath.Join(g.c.RepoRoot, rel, "testdata")
	st, err := os.Stat(testdataPath)
	hasTestdata := err == nil && st.IsDir()

	if r := g.generateTest(rel, pkg, library, hasTestdata); r != nil {
		rules = append(rules, r)
	}

	if r := g.generateXTest(rel, pkg, library, hasTestdata); r != nil {
		rules = append(rules, r)
	}

	return rules
}

func (g *generator) generateBin(rel string, pkg *packages.Package, library string) *bzl.Rule {
	if !pkg.IsCommand() || pkg.Binary.Sources.IsEmpty() && library == "" {
		return nil
	}
	name := filepath.Base(pkg.Dir)
	visibility := checkInternalVisibility(rel, "//visibility:public")
	return g.generateRule(rel, "go_binary", name, visibility, library, false, pkg.Binary)
}

func (g *generator) generateLib(rel string, pkg *packages.Package, cgoName string) (string, *bzl.Rule) {
	if !pkg.Library.HasGo() && cgoName == "" {
		return "", nil
	}

	name := defaultLibName
	var visibility string
	if pkg.IsCommand() {
		// Libraries made for a go_binary should not be exposed to the public.
		visibility = "//visibility:private"
	} else {
		visibility = checkInternalVisibility(rel, "//visibility:public")
	}

	rule := g.generateRule(rel, "go_library", name, visibility, cgoName, false, pkg.Library)
	return name, rule
}

func (g *generator) generateCgoLib(rel string, pkg *packages.Package) (string, *bzl.Rule) {
	if !pkg.CgoLibrary.HasGo() {
		return "", nil
	}

	name := defaultCgoLibName
	visibility := "//visibility:private"
	rule := g.generateRule(rel, "cgo_library", name, visibility, "", false, pkg.CgoLibrary)
	return name, rule
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
func (g *generator) filegroup(rel string, pkg *packages.Package) *bzl.Rule {
	if !pkg.HasPbGo || len(pkg.Protos) == 0 {
		return nil
	}
	return newRule("filegroup", nil, []keyvalue{
		{key: "name", value: defaultProtosName},
		{key: "srcs", value: pkg.Protos},
		{key: "visibility", value: []string{"//visibility:public"}},
	})
}

func (g *generator) generateTest(rel string, pkg *packages.Package, library string, hasTestdata bool) *bzl.Rule {
	if !pkg.Test.HasGo() {
		return nil
	}

	var name string
	if library == "" || library == defaultLibName {
		name = defaultTestName
	} else {
		name = library + "_test"
	}

	return g.generateRule(rel, "go_test", name, "", library, hasTestdata, pkg.Test)
}

func (g *generator) generateXTest(rel string, pkg *packages.Package, library string, hasTestdata bool) *bzl.Rule {
	if !pkg.XTest.HasGo() {
		return nil
	}

	var name string
	if library == "" || library == defaultLibName {
		name = defaultXTestName
	} else {
		name = library + "_xtest"
	}

	return g.generateRule(rel, "go_test", name, "", "", hasTestdata, pkg.XTest)
}

func (g *generator) generateRule(rel, kind, name, visibility, library string, hasTestdata bool, target packages.Target) *bzl.Rule {
	// Construct attrs in the same order that bzl.Rewrite uses. See
	// namePriority in github.com/bazelbuild/buildtools/build/rewrite.go.
	attrs := []keyvalue{
		{"name", name},
	}
	if !target.Sources.IsEmpty() {
		attrs = append(attrs, keyvalue{"srcs", target.Sources})
	}
	if !target.CLinkOpts.IsEmpty() {
		attrs = append(attrs, keyvalue{"clinkopts", target.CLinkOpts})
	}
	if !target.COpts.IsEmpty() {
		attrs = append(attrs, keyvalue{"copts", target.COpts})
	}
	if hasTestdata {
		glob := globvalue{patterns: []string{"testdata/**"}}
		attrs = append(attrs, keyvalue{"data", glob})
	}
	if library != "" {
		attrs = append(attrs, keyvalue{"library", ":" + library})
	}
	if visibility != "" {
		attrs = append(attrs, keyvalue{"visibility", []string{visibility}})
	}
	if !target.Imports.IsEmpty() {
		deps := g.dependencies(target.Imports, rel)
		attrs = append(attrs, keyvalue{"deps", deps})
	}
	return newRule(kind, nil, attrs)
}

func (g *generator) dependencies(imports packages.PlatformStrings, dir string) packages.PlatformStrings {
	resolve := func(imp string) (string, error) {
		if l, err := g.r.resolve(imp, dir); err != nil {
			return "", fmt.Errorf("in dir %q, could not resolve import path %q: %v", dir, imp, err)
		} else {
			return l.String(), nil
		}
	}

	deps, errors := imports.Map(resolve)
	for _, err := range errors {
		log.Print(err)
	}
	deps.Clean()
	return deps
}

// isRelative determines if an importpath is relative.
func isRelative(importpath string) bool {
	return strings.HasPrefix(importpath, "./") || strings.HasPrefix(importpath, "..")
}
