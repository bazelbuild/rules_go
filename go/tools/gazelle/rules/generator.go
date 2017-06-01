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
	"go/build"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"

	bzl "github.com/bazelbuild/buildtools/build"
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

// ExternalResolver resolves external packages.
type ExternalResolver int

const (
	// External resolves external packages as external packages with
	// new_go_repository.
	External ExternalResolver = iota
	// Vendored resolves external packages as vendored packages in vendor/.
	Vendored
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
	Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error)
}

// NewGenerator returns an implementation of Generator.
//
// "repoRoot" is a path to the root directory of the repository.
// "goPrefix" is the go_prefix corresponding to the repository root.
// See also https://github.com/bazelbuild/rules_go#go_prefix.
// "external" is how external packages should be resolved.
func NewGenerator(repoRoot string, goPrefix string, external ExternalResolver) Generator {
	var (
		// TODO(yugui) Support another resolver to cover the pattern 2 in
		// https://github.com/bazelbuild/rules_go/issues/16#issuecomment-216010843
		r = structuredResolver{goPrefix: goPrefix}
	)

	var e labelResolver
	switch external {
	case External:
		e = externalResolver{}
	case Vendored:
		e = vendoredResolver{}
	default:
		return nil
	}

	return &generator{
		repoRoot: repoRoot,
		goPrefix: goPrefix,
		r: resolverFunc(func(importpath, dir string) (label, error) {
			if importpath != goPrefix && !strings.HasPrefix(importpath, goPrefix+"/") && !isRelative(importpath) {
				return e.resolve(importpath, dir)
			}
			return r.resolve(importpath, dir)
		}),
	}
}

type generator struct {
	repoRoot string
	goPrefix string
	r        labelResolver
}

func (g *generator) Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error) {
	var rules []*bzl.Rule
	if rel == "" {
		p, err := newRule("go_prefix", []interface{}{g.goPrefix}, nil)
		if err != nil {
			return nil, err
		}
		rules = append(rules, p)
	}

	cgoLibrary := ""
	if len(pkg.CgoFiles) != 0 {
		cgoLibrary = defaultCgoLibName
		r, err := g.generateCgoCLib(rel, cgoLibrary, pkg)
		if err != nil {
			return nil, err
		}
		rules = append(rules, r)
	}

	library := defaultLibName
	libRule, err := g.generateLib(rel, library, pkg, cgoLibrary)
	if err != nil {
		return nil, err
	}
	if libRule != nil {
		rules = append(rules, libRule)
	}

	if pkg.IsCommand() {
		r, err := g.generateBin(rel, library, pkg)
		if err != nil {
			return nil, err
		}
		rules = append(rules, r)
	}

	p, err := g.filegroup(rel, pkg)
	if err != nil {
		return nil, err
	}
	if p != nil {
		rules = append(rules, p)
	}

	testdataPath := filepath.Join(g.repoRoot, rel, "testdata")
	st, err := os.Stat(testdataPath)
	hasTestdata := err == nil && st.IsDir()
	if len(pkg.TestGoFiles) > 0 {
		t, err := g.generateTest(rel, pkg, library, hasTestdata, libRule != nil)
		if err != nil {
			return nil, err
		}
		rules = append(rules, t)
	}

	if len(pkg.XTestGoFiles) > 0 {
		t, err := g.generateXTest(rel, pkg, library, hasTestdata)
		if err != nil {
			return nil, err
		}
		rules = append(rules, t)
	}
	return rules, nil
}

func (g *generator) generateBin(rel, library string, pkg *build.Package) (*bzl.Rule, error) {
	kind := "go_binary"
	name := path.Base(pkg.Dir)

	visibility := checkInternalVisibility(rel, "//visibility:public")
	attrs := []keyvalue{
		{key: "name", value: name},
		{key: "library", value: ":" + library},
		{key: "visibility", value: []string{visibility}},
	}

	return newRule(kind, nil, attrs)
}

func (g *generator) generateLib(rel, name string, pkg *build.Package, cgoName string) (*bzl.Rule, error) {
	kind := "go_library"

	visibility := "//visibility:public"
	// Libraries made for a go_binary should not be exposed to the public.
	if pkg.IsCommand() {
		visibility = "//visibility:private"
	}

	attrs := []keyvalue{
		{key: "name", value: name},
	}

	srcs := append([]string{}, pkg.GoFiles...)
	if cgoName == "" {
		srcs = append(srcs, pkg.SFiles...)
		if len(srcs) == 0 {
			return nil, nil
		}
		srcs = append(srcs, pkg.HFiles...)
		attrs = append(attrs, keyvalue{key: "srcs", value: srcs})
	} else {
		// go_library gets mad when an empty slice is passed in, but handles not
		// being set at all just fine when "library" is set.
		if len(srcs) > 0 {
			attrs = append(attrs, keyvalue{key: "srcs", value: srcs})
		}
		attrs = append(attrs, keyvalue{key: "library", value: ":" + cgoName})
	}
	visibility = checkInternalVisibility(rel, visibility)

	attrs = append(attrs, keyvalue{key: "visibility", value: []string{visibility}})

	deps, err := g.dependencies(pkg.Imports, rel)
	if err != nil {
		return nil, err
	}
	if len(deps) > 0 {
		attrs = append(attrs, keyvalue{key: "deps", value: deps})
	}

	return newRule(kind, nil, attrs)
}

// generateCgoCLib generates a cgo_library rule for C/C++ code.
func (g *generator) generateCgoCLib(rel, name string, pkg *build.Package) (*bzl.Rule, error) {
	kind := "cgo_library"

	attrs := []keyvalue{
		{key: "name", value: name},
	}

	if len(pkg.MFiles) != 0 {
		log.Printf("warning: %s has Objective-C files but rules_go does not yet support Objective-C", rel)
	}
	if len(pkg.FFiles) != 0 {
		log.Printf("warning: %s has Fortran files but rules_go does not yet support Fortran", rel)
	}
	if len(pkg.SwigFiles) != 0 || len(pkg.SwigCXXFiles) != 0 {
		log.Printf("warning: %s has SWIG files but rules_go does not yet support SWIG", rel)
	}

	srcs := append([]string{}, pkg.CgoFiles...)
	srcs = append(srcs, pkg.CFiles...)
	srcs = append(srcs, pkg.CXXFiles...)
	srcs = append(srcs, pkg.HFiles...)
	srcs = append(srcs, pkg.SFiles...)
	attrs = append(attrs, keyvalue{key: "srcs", value: srcs})

	copts := append([]string{}, pkg.CgoCFLAGS...)
	copts = append(copts, pkg.CgoCPPFLAGS...)
	copts = append(copts, pkg.CgoCXXFLAGS...)
	if len(copts) > 0 {
		attrs = append(attrs, keyvalue{key: "copts", value: copts})
	}
	if len(pkg.CgoLDFLAGS) > 0 {
		attrs = append(attrs, keyvalue{key: "clinkopts", value: pkg.CgoLDFLAGS})
	}

	visibility := checkInternalVisibility(rel, "//visibility:private")
	attrs = append(attrs, keyvalue{key: "visibility", value: []string{visibility}})

	deps, err := g.dependencies(pkg.Imports, rel)
	if err != nil {
		return nil, err
	}
	if len(deps) > 0 {
		attrs = append(attrs, keyvalue{key: "deps", value: deps})
	}

	return newRule(kind, nil, attrs)
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
func (g *generator) filegroup(rel string, pkg *build.Package) (*bzl.Rule, error) {
	if !hasPbGo(pkg.GoFiles) {
		return nil, nil
	}
	protos, err := filepath.Glob(pkg.Dir + "/*.proto")
	if err != nil {
		return nil, err
	}
	if len(protos) == 0 {
		return nil, nil
	}
	for i, p := range protos {
		protos[i] = filepath.Base(p)
	}
	return newRule("filegroup", nil, []keyvalue{
		{key: "name", value: defaultProtosName},
		{key: "srcs", value: protos},
		{key: "visibility", value: []string{"//visibility:public"}},
	})
}

func hasPbGo(files []string) bool {
	for _, s := range files {
		if strings.HasSuffix(s, ".pb.go") {
			return true
		}
	}
	return false
}

func (g *generator) generateTest(rel string, pkg *build.Package, library string, hasTestdata, hasLib bool) (*bzl.Rule, error) {
	name := library + "_test"
	if library == defaultLibName {
		name = defaultTestName
	}
	attrs := []keyvalue{
		{key: "name", value: name},
		{key: "srcs", value: pkg.TestGoFiles},
	}
	if hasTestdata {
		glob := globvalue{patterns: []string{"testdata/**"}}
		attrs = append(attrs, keyvalue{key: "data", value: glob})
	}
	if hasLib {
		attrs = append(attrs, keyvalue{key: "library", value: ":" + library})
	}

	deps, err := g.dependencies(pkg.TestImports, rel)
	if err != nil {
		return nil, err
	}
	if len(deps) > 0 {
		attrs = append(attrs, keyvalue{key: "deps", value: deps})
	}
	return newRule("go_test", nil, attrs)
}

func (g *generator) generateXTest(rel string, pkg *build.Package, library string, hasTestdata bool) (*bzl.Rule, error) {
	name := library + "_xtest"
	if library == defaultLibName {
		name = defaultXTestName
	}
	attrs := []keyvalue{
		{key: "name", value: name},
		{key: "srcs", value: pkg.XTestGoFiles},
	}
	if hasTestdata {
		glob := globvalue{patterns: []string{"testdata/**"}}
		attrs = append(attrs, keyvalue{key: "data", value: glob})
	}

	deps, err := g.dependencies(pkg.XTestImports, rel)
	if err != nil {
		return nil, err
	}
	if len(deps) > 0 {
		attrs = append(attrs, keyvalue{key: "deps", value: deps})
	}
	return newRule("go_test", nil, attrs)
}

func (g *generator) dependencies(imports []string, dir string) ([]string, error) {
	var deps []string
	for _, p := range imports {
		if isStandard(p, g.goPrefix) {
			continue
		}
		l, err := g.r.resolve(p, dir)
		if err != nil {
			log.Printf("in dir %q, could not resolve import path %q: %v", dir, p, err)
			continue
		}
		deps = append(deps, l.String())
	}
	return deps, nil
}

// isStandard determines if importpath points a Go standard package.
func isStandard(importpath, goPrefix string) bool {
	seg := strings.SplitN(importpath, "/", 2)[0]
	return !strings.Contains(seg, ".") && !strings.HasPrefix(importpath, goPrefix+"/")
}

// isRelative determines if an importpath is relative.
func isRelative(importpath string) bool {
	return strings.HasPrefix(importpath, "./") || strings.HasPrefix(importpath, "..")
}
