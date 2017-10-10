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
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/resolve"
)

// NewGenerator returns a new instance of Generator.
// "buildRel" is a slash-separated path to the directory containing the
// build file being generated, relative to the repository root.
// "oldFile" is the existing build file. May be nil.
func NewGenerator(c *config.Config, r *resolve.Resolver, l resolve.Labeler, buildRel string, oldFile *bf.File) *Generator {
	shouldSetVisibility := oldFile == nil || !hasDefaultVisibility(oldFile)
	return &Generator{c: c, r: r, l: l, buildRel: buildRel, shouldSetVisibility: shouldSetVisibility}
}

// Generator generates Bazel build rules for Go build targets.
type Generator struct {
	c                   *config.Config
	r                   *resolve.Resolver
	l                   resolve.Labeler
	buildRel            string
	shouldSetVisibility bool
}

// GenerateRules generates a list of rules for targets in "pkg". It also returns
// a list of empty rules that may be deleted from an existing file.
func (g *Generator) GenerateRules(pkg *packages.Package) (rules []bf.Expr, empty []bf.Expr) {
	var rs []bf.Expr

	protoLibName, protoRules := g.generateProto(pkg)
	rs = append(rs, protoRules...)

	libName, libRule := g.generateLib(pkg, protoLibName)
	rs = append(rs, libRule)

	rs = append(rs,
		g.generateBin(pkg, libName),
		g.generateTest(pkg, libName, false),
		g.generateTest(pkg, "", true))

	for _, r := range rs {
		if isEmpty(r) {
			empty = append(empty, r)
		} else {
			rules = append(rules, r)
		}
	}
	return rules, empty
}

func (g *Generator) generateProto(pkg *packages.Package) (string, []bf.Expr) {
	if g.c.ProtoMode == config.DisableProtoMode {
		// Don't create or delete proto rules in this mode. Any existing rules
		// are likely hand-written.
		return "", nil
	}

	filegroupName := config.DefaultProtosName
	protoName := g.l.ProtoLabel(pkg.Rel, pkg.Name).Name
	goProtoName := g.l.GoProtoLabel(pkg.Rel, pkg.Name).Name

	if g.c.ProtoMode == config.LegacyProtoMode {
		if !pkg.Proto.HasProto() {
			return "", []bf.Expr{emptyRule("filegroup", filegroupName)}
		}
		return "", []bf.Expr{
			newRule("filegroup", []keyvalue{
				{key: "name", value: filegroupName},
				{key: "srcs", value: g.sources(pkg.Proto.Sources, pkg.Rel)},
				{key: "visibility", value: []string{"//visibility:public"}},
			}),
		}
	}

	if !pkg.Proto.HasProto() {
		return "", []bf.Expr{
			emptyRule("filegroup", filegroupName),
			emptyRule("proto_library", protoName),
			emptyRule("go_proto_library", goProtoName),
			emptyRule("go_grpc_library", goProtoName),
		}
	}

	var rules []bf.Expr
	visibility := []string{checkInternalVisibility(pkg.Rel, "//visibility:public")}
	protoAttrs := []keyvalue{
		{"name", protoName},
		{"srcs", g.sources(pkg.Proto.Sources, pkg.Rel)},
		{"visibility", visibility},
	}
	if !pkg.Proto.Imports.IsEmpty() {
		protoAttrs = append(protoAttrs,
			keyvalue{"deps", g.dependencies(pkg.Proto.Imports, g.r.ResolveProto)})
	}
	rules = append(rules, newRule("proto_library", protoAttrs))

	goProtoAttrs := []keyvalue{
		{"name", goProtoName},
		{"proto", ":" + protoName},
		{"importpath", pkg.ImportPath(g.c.GoPrefix)},
		{"visibility", visibility},
	}
	if !pkg.Proto.Imports.IsEmpty() {
		goProtoAttrs = append(goProtoAttrs,
			keyvalue{"deps", g.dependencies(pkg.Proto.Imports, g.r.ResolveGoProto)})
	}

	// If a developer adds or removes services from existing protos, this
	// will create a new rule and delete the old one, along with any custom
	// attributes (assuming no keep comments). We can't currently merge
	// rules unless both kind and name match.
	if pkg.Proto.HasServices {
		rules = append(rules,
			newRule("go_grpc_library", goProtoAttrs),
			emptyRule("go_proto_library", goProtoName))
	} else {
		rules = append(rules,
			newRule("go_proto_library", goProtoAttrs),
			emptyRule("go_grpc_library", goProtoName))
	}

	return goProtoName, rules
}

func (g *Generator) generateBin(pkg *packages.Package, library string) bf.Expr {
	name := g.l.BinaryLabel(pkg.Rel).Name
	if !pkg.IsCommand() || pkg.Binary.Sources.IsEmpty() && library == "" {
		return emptyRule("go_binary", name)
	}
	visibility := checkInternalVisibility(pkg.Rel, "//visibility:public")
	attrs := g.commonAttrs(pkg.Rel, name, visibility, pkg.Binary)
	// TODO(jayconrod): don't add importpath if it can be inherited from library.
	// This is blocked by bazelbuild/bazel#3575.
	attrs = append(attrs, keyvalue{"importpath", pkg.ImportPath(g.c.GoPrefix)})
	if library != "" {
		attrs = append(attrs, keyvalue{"library", ":" + library})
	}
	return newRule("go_binary", attrs)
}

func (g *Generator) generateLib(pkg *packages.Package, goProtoName string) (string, *bf.CallExpr) {
	name := g.l.LibraryLabel(pkg.Rel).Name
	if !pkg.Library.HasGo() && goProtoName == "" {
		return "", emptyRule("go_library", name)
	}
	var visibility string
	if pkg.IsCommand() {
		// Libraries made for a go_binary should not be exposed to the public.
		visibility = "//visibility:private"
	} else {
		visibility = checkInternalVisibility(pkg.Rel, "//visibility:public")
	}

	attrs := g.commonAttrs(pkg.Rel, name, visibility, pkg.Library)
	attrs = append(attrs, keyvalue{"importpath", pkg.ImportPath(g.c.GoPrefix)})
	if goProtoName != "" {
		attrs = append(attrs, keyvalue{"library", ":" + goProtoName})
	}

	rule := newRule("go_library", attrs)
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

func (g *Generator) generateTest(pkg *packages.Package, library string, isXTest bool) bf.Expr {
	name := g.l.TestLabel(pkg.Rel, isXTest).Name
	target := pkg.Test
	importpath := pkg.ImportPath(g.c.GoPrefix)
	if isXTest {
		target = pkg.XTest
		importpath += "_test"
	}
	if !target.HasGo() {
		return emptyRule("go_test", name)
	}
	attrs := g.commonAttrs(pkg.Rel, name, "", target)
	// TODO(jayconrod): don't add importpath if it can be inherited from library.
	// This is blocked by bazelbuild/bazel#3575.
	attrs = append(attrs, keyvalue{"importpath", importpath})
	if library != "" {
		attrs = append(attrs, keyvalue{"library", ":" + library})
	}
	if pkg.HasTestdata {
		glob := globvalue{patterns: []string{path.Join(g.buildPkgRel(pkg.Rel), "testdata/**")}}
		attrs = append(attrs, keyvalue{"data", glob})
	}
	if g.c.StructureMode == config.FlatMode {
		attrs = append(attrs, keyvalue{"rundir", pkg.Rel})
	}
	return newRule("go_test", attrs)
}

func (g *Generator) commonAttrs(pkgRel, name, visibility string, target packages.GoTarget) []keyvalue {
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
		resolveFunc := func(imp string) (resolve.Label, error) {
			return g.r.ResolveGo(imp, pkgRel)
		}
		attrs = append(attrs, keyvalue{"deps", g.dependencies(target.Imports, resolveFunc)})
	}
	return attrs
}

// sources converts paths in "srcs" which are relative to the Go package
// directory ("pkgRel") into relative paths to the build file
// being generated ("g.buildRel").
func (g *Generator) sources(srcs packages.PlatformStrings, pkgRel string) packages.PlatformStrings {
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
func (g *Generator) buildPkgRel(pkgRel string) string {
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

type resolveFunc func(imp string) (resolve.Label, error)

// dependencies converts import paths in "imports" into Bazel labels.
func (g *Generator) dependencies(imports packages.PlatformStrings, resolve resolveFunc) packages.PlatformStrings {
	resolveToString := func(imp string) (string, error) {
		label, err := resolve(imp)
		if err != nil {
			return "", err
		}
		label.Relative = label.Repo == "" && label.Pkg == g.buildRel
		return label.String(), nil
	}

	deps, errors := imports.Map(resolveToString)
	for _, err := range errors {
		log.Print(err)
	}
	deps.Clean()
	return deps
}

var (
	// shortOptPrefixes are strings that come at the beginning of an option
	// argument that includes a path, e.g., -Ifoo/bar.
	shortOptPrefixes = []string{"-I", "-L", "-F"}

	// longOptPrefixes are separate arguments that come before a path argument,
	// e.g., -iquote foo/bar.
	longOptPrefixes = []string{"-I", "-L", "-F", "-iquote", "-isystem"}
)

// options transforms package-relative paths in cgo options into repository-
// root-relative paths that Bazel can understand. For example, if a cgo file
// in //foo declares an include flag in its copts: "-Ibar", this method
// will transform that flag into "-Ifoo/bar".
func (g *Generator) options(opts packages.PlatformStrings, pkgRel string) packages.PlatformStrings {
	fixPath := func(opt string) string {
		if strings.HasPrefix(opt, "/") {
			return opt
		}
		return path.Clean(path.Join(pkgRel, opt))
	}

	fixOpts := func(opts []string) ([]string, error) {
		fixedOpts := make([]string, len(opts))
		isPath := false
		for i, opt := range opts {
			if isPath {
				opt = fixPath(opt)
				isPath = false
				goto next
			}

			for _, short := range shortOptPrefixes {
				if strings.HasPrefix(opt, short) && len(opt) > len(short) {
					opt = short + fixPath(opt[len(short):])
					goto next
				}
			}

			for _, long := range longOptPrefixes {
				if opt == long {
					isPath = true
					goto next
				}
			}

		next:
			fixedOpts[i] = opt
		}

		return packages.JoinOptions(fixedOpts), nil
	}

	opts, errs := opts.MapSlice(fixOpts)
	if errs != nil {
		log.Panicf("unexpected error when transforming options with pkg %q: %v", pkgRel, errs)
	}
	return opts
}

func isEmpty(r bf.Expr) bool {
	c, ok := r.(*bf.CallExpr)
	return ok && len(c.List) == 1 // name
}
