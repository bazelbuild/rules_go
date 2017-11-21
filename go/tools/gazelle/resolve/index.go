/* Copyright 2017 The Bazel Authors. All rights reserved.

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
	"log"
	"path"
	"path/filepath"
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// RuleIndex is a table of rules in a workspace, indexed by label and by
// import path. Used by Resolver to map import paths to labels.
type RuleIndex struct {
	rules     []*ruleRecord
	labelMap  map[Label]*ruleRecord
	importMap map[importSpec][]*ruleRecord
}

// ruleRecord contains information about a rule relevant to import indexing.
type ruleRecord struct {
	call       *bf.CallExpr
	label      Label
	lang       config.Language
	importedAs []importSpec
	visibility visibilitySpec
	generated  bool
	replaced   bool
}

// importSpec describes a package to be imported. Language is specified, since
// different languages have different formats for their imports.
type importSpec struct {
	lang config.Language
	imp  string
}

// visibilitySpec describes the visibility of a rule. Gazelle only attempts
// to address common cases here: we handle "//visibility:public",
// "//visibility:private", and "//path/to/pkg:__subpackages__" (which is
// represented here as a relative path, e.g., "path/to/pkg".
type visibilitySpec []string

func NewRuleIndex() *RuleIndex {
	return &RuleIndex{
		labelMap: make(map[Label]*ruleRecord),
	}
}

// AddRulesFromFile adds existing rules to the index from oldFile
// (which must not be nil).
func (ix *RuleIndex) AddRulesFromFile(c *config.Config, oldFile *bf.File) {
	buildRel, err := filepath.Rel(c.RepoRoot, oldFile.Path)
	if err != nil {
		log.Panicf("file not in repo: %s", oldFile.Path)
	}
	buildRel = path.Dir(filepath.ToSlash(buildRel))
	defaultVisibility := findDefaultVisibility(oldFile, buildRel)
	for _, stmt := range oldFile.Stmt {
		if call, ok := stmt.(*bf.CallExpr); ok {
			ix.addRule(call, c.GoPrefix, buildRel, defaultVisibility, false)
		}
	}
}

// AddGeneratedRules adds newly generated rules to the index. These may
// replace existing rules with the same label.
func (ix *RuleIndex) AddGeneratedRules(c *config.Config, buildRel string, oldFile *bf.File, rules []bf.Expr) {
	defaultVisibility := findDefaultVisibility(oldFile, buildRel)
	for _, stmt := range rules {
		if call, ok := stmt.(*bf.CallExpr); ok {
			ix.addRule(call, c.GoPrefix, buildRel, defaultVisibility, true)
		}
	}
}

func (ix *RuleIndex) addRule(call *bf.CallExpr, goPrefix, buildRel string, defaultVisibility []string, generated bool) {
	rule := bf.Rule{Call: call}
	record := &ruleRecord{
		call:      call,
		label:     Label{Pkg: buildRel, Name: rule.Name()},
		generated: generated,
	}

	if old, ok := ix.labelMap[record.label]; ok {
		if !old.generated && !generated {
			log.Printf("multiple rules found with label %s", record.label)
		}
		if old.generated && generated {
			log.Panicf("multiple rules generated with label %s", record.label)
		}
		if !generated {
			// Don't index an existing rule if we already have a generated rule
			// of the same name.
			return
		}
		old.replaced = true
	}

	kind := rule.Kind()
	switch kind {
	case "go_library":
		record.lang = config.GoLang
		record.importedAs = []importSpec{{lang: config.GoLang, imp: getGoImportPath(rule, goPrefix, buildRel)}}

	case "go_proto_library", "go_grpc_library":
		record.lang = config.GoLang
		// importedAs is set in Finish, since we need to dereference the "proto"
		// attribute to find the sources. These rules are not automatically
		// importable from Go.

	case "proto_library":
		record.lang = config.ProtoLang
		for _, s := range findSources(rule, buildRel, ".proto") {
			record.importedAs = append(record.importedAs, importSpec{lang: config.ProtoLang, imp: s})
		}

	default:
		return
	}

	visExpr := rule.Attr("visibility")
	if visExpr != nil {
		record.visibility = parseVisibility(visExpr, buildRel)
	} else {
		record.visibility = defaultVisibility
	}

	ix.rules = append(ix.rules, record)
	ix.labelMap[record.label] = record
}

// Finish constructs the import index and performs any other necessary indexing
// actions after all rules have been added. This step is necessary because
// some rules that are added may later be replaced (existing rules may be
// replaced by generated rules). Also, for proto rules, we need to be able
// to dereference a label to find the sources.
//
// This function must be called after all AddRulesFromFile and AddGeneratedRules
// calls but before any findRuleByImport calls.
func (ix *RuleIndex) Finish() {
	ix.importMap = make(map[importSpec][]*ruleRecord)
	oldRules := ix.rules
	ix.rules = nil
	for _, r := range oldRules {
		if r.replaced {
			continue
		}
		rule := bf.Rule{Call: r.call}
		kind := rule.Kind()
		if kind == "go_proto_library" || kind == "go_grpc_library" {
			r.importedAs = findGoProtoSources(ix, r)
		}
		for _, imp := range r.importedAs {
			ix.importMap[imp] = append(ix.importMap[imp], r)
		}
	}
}

type ruleNotFoundError struct {
	imp     string
	fromRel string
}

func (e ruleNotFoundError) Error() string {
	return fmt.Sprintf("no rule found for %q visible from %s", e.imp, e.fromRel)
}

func (ix *RuleIndex) findRuleByLabel(label Label, fromRel string) (*ruleRecord, error) {
	label = label.Abs("", fromRel)
	r, ok := ix.labelMap[label]
	if !ok {
		return nil, ruleNotFoundError{label.String(), fromRel}
	}
	return r, nil
}

// findRuleByImport attempts to resolve an import string to a rule record.
// imp is the import to resolve (which includes the target language). lang is
// the language of the rule with the dependency (for example, in
// go_proto_library, imp will have ProtoLang and lang will be GoLang).
// fromRel is the slash-separated path to the directory containing the import,
// relative to the repository root.
//
// Any number of rules may provide the same import. If no rules provide
// the import, ruleNotFoundError is returned. If multiple rules provide the
// import, this function will attempt to choose one based on visibility.
// An error is returned if the import is still ambiguous.
//
// Note that a rule may be returned even if visibility restrictions will be
// be violated. Bazel will give a descriptive error message when a build
// is attempted.
func (ix *RuleIndex) findRuleByImport(imp importSpec, lang config.Language, fromRel string) (*ruleRecord, error) {
	matches := ix.importMap[imp]
	var bestMatches []*ruleRecord
	bestMatchesAreVisible := false
	for _, m := range matches {
		if m.lang != lang {
			continue
		}
		visible := isVisibleFrom(m.visibility, m.label.Pkg, fromRel)
		if bestMatchesAreVisible && !visible {
			continue
		}
		if !bestMatchesAreVisible && visible {
			bestMatchesAreVisible = true
			bestMatches = nil
		}
		bestMatches = append(bestMatches, m)
	}
	if len(bestMatches) == 0 {
		return nil, ruleNotFoundError{imp.imp, fromRel}
	}
	if len(bestMatches) >= 2 {
		return nil, fmt.Errorf("multiple rules (%s and %s) may be imported with %q", bestMatches[0].label, bestMatches[1].label, imp.imp)
	}
	return bestMatches[0], nil
}

func (ix *RuleIndex) findLabelByImport(imp importSpec, lang config.Language, fromRel string) (Label, error) {
	r, err := ix.findRuleByImport(imp, lang, fromRel)
	if err != nil {
		return NoLabel, err
	}
	return r.label, nil
}

func getGoImportPath(r bf.Rule, goPrefix, buildRel string) string {
	// TODO(#597): account for subdirectory where goPrefix was set, when we
	// support multiple prefixes.
	imp := r.AttrString("importpath")
	if imp != "" {
		return imp
	}
	imp = path.Join(goPrefix, buildRel)
	if name := r.Name(); name != config.DefaultLibName {
		imp = path.Join(imp, name)
	}
	return imp
}

func findGoProtoSources(ix *RuleIndex, r *ruleRecord) []importSpec {
	rule := bf.Rule{Call: r.call}
	protoExpr, ok := rule.Attr("proto").(*bf.StringExpr)
	if !ok {
		return nil
	}
	protoLabel, err := ParseLabel(protoExpr.Value)
	if err != nil {
		return nil
	}
	protoRule, err := ix.findRuleByLabel(protoLabel, r.label.Pkg)
	if err != nil {
		return nil
	}
	var importedAs []importSpec
	for _, source := range findSources(bf.Rule{Call: protoRule.call}, protoRule.label.Pkg, ".proto") {
		importedAs = append(importedAs, importSpec{lang: config.ProtoLang, imp: source})
	}
	return importedAs
}

func findSources(r bf.Rule, buildRel, ext string) []string {
	srcsExpr := r.Attr("srcs")
	srcsList, ok := srcsExpr.(*bf.ListExpr)
	if !ok {
		return nil
	}
	var srcs []string
	for _, srcExpr := range srcsList.List {
		src, ok := srcExpr.(*bf.StringExpr)
		if !ok {
			continue
		}
		label, err := ParseLabel(src.Value)
		if err != nil || !label.Relative || !strings.HasSuffix(label.Name, ext) {
			continue
		}
		srcs = append(srcs, path.Join(buildRel, label.Name))
	}
	return srcs
}

func findDefaultVisibility(oldFile *bf.File, buildRel string) visibilitySpec {
	if oldFile == nil {
		return visibilitySpec{config.PrivateVisibility}
	}
	for _, stmt := range oldFile.Stmt {
		call, ok := stmt.(*bf.CallExpr)
		if !ok {
			continue
		}
		rule := bf.Rule{Call: call}
		if rule.Kind() == "package" {
			return parseVisibility(rule.Attr("default_visibility"), buildRel)
		}
	}
	return visibilitySpec{config.PrivateVisibility}
}

func parseVisibility(visExpr bf.Expr, buildRel string) visibilitySpec {
	visList, ok := visExpr.(*bf.ListExpr)
	if !ok {
		return visibilitySpec{config.PrivateVisibility}
	}
	var visibility visibilitySpec
	for _, elemExpr := range visList.List {
		elemStr, ok := elemExpr.(*bf.StringExpr)
		if !ok {
			continue
		}
		if elemStr.Value == config.PublicVisibility || elemStr.Value == config.PrivateVisibility {
			visibility = append(visibility, elemStr.Value)
			continue
		}
		label, err := ParseLabel(elemStr.Value)
		if err != nil {
			continue
		}
		label = label.Abs("", buildRel)
		if label.Repo != "" || label.Name != "__subpackages__" {
			continue
		}
		visibility = append(visibility, label.Pkg)
	}
	return visibility
}

func isVisibleFrom(visibility visibilitySpec, defRel, useRel string) bool {
	for _, vis := range visibility {
		switch vis {
		case config.PublicVisibility:
			return true
		case config.PrivateVisibility:
			return defRel == useRel
		default:
			return useRel == vis || strings.HasPrefix(useRel, vis+"/")
		}
	}
	return false
}
