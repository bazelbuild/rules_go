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
	rule       bf.Rule
	label      Label
	lang       config.Language
	importedAs []importSpec
	generated  bool
	replaced   bool
	embedded   bool
}

// importSpec describes a package to be imported. Language is specified, since
// different languages have different formats for their imports.
type importSpec struct {
	lang config.Language
	imp  string
}

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
	if buildRel == "." || buildRel == "/" {
		buildRel = ""
	}

	for _, stmt := range oldFile.Stmt {
		if call, ok := stmt.(*bf.CallExpr); ok {
			ix.addRule(call, c.GoPrefix, buildRel, false)
		}
	}
}

// AddGeneratedRules adds newly generated rules to the index. These may
// replace existing rules with the same label.
func (ix *RuleIndex) AddGeneratedRules(c *config.Config, buildRel string, rules []bf.Expr) {
	for _, stmt := range rules {
		if call, ok := stmt.(*bf.CallExpr); ok {
			ix.addRule(call, c.GoPrefix, buildRel, true)
		}
	}
}

func (ix *RuleIndex) addRule(call *bf.CallExpr, goPrefix, buildRel string, generated bool) {
	rule := bf.Rule{Call: call}
	record := &ruleRecord{
		rule:      rule,
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
	switch {
	case isGoLibrary(kind):
		record.lang = config.GoLang
		if imp := rule.AttrString("importpath"); imp != "" {
			record.importedAs = []importSpec{{lang: config.GoLang, imp: imp}}
		}
		// Additional proto imports may be added in Finish.

	case kind == "proto_library":
		record.lang = config.ProtoLang
		for _, s := range findSources(rule, buildRel, ".proto") {
			record.importedAs = append(record.importedAs, importSpec{lang: config.ProtoLang, imp: s})
		}

	default:
		return
	}

	ix.rules = append(ix.rules, record)
	ix.labelMap[record.label] = record
}

// Finish constructs the import index and performs any other necessary indexing
// actions after all rules have been added. This step is necessary because
// a rule may be indexed differently based on what rules are added later.
//
// This function must be called after all AddRulesFromFile and AddGeneratedRules
// calls but before any findRuleByImport calls.
func (ix *RuleIndex) Finish() {
	ix.removeReplacedRules()
	ix.skipGoEmbds()
	ix.buildImportIndex()
}

// removeReplacedRules removes rules from existing files that were replaced
// by generated rules.
func (ix *RuleIndex) removeReplacedRules() {
	oldRules := ix.rules
	ix.rules = nil
	for _, r := range oldRules {
		if !r.replaced {
			ix.rules = append(ix.rules, r)
		}
	}
}

// skipGoEmbeds sets the embedded flag on Go library rules that are imported
// by other Go library rules with the same import path. Note that embedded
// rules may still be imported with non-Go imports. For example, a
// go_proto_library may be imported with either a Go import path or a proto
// path. If the library is embedded, only the proto path will be indexed.
func (ix *RuleIndex) skipGoEmbds() {
	for _, r := range ix.rules {
		if !isGoLibrary(r.rule.Kind()) {
			continue
		}
		importpath := r.rule.AttrString("importpath")

		var embedLabels []Label
		if embedList, ok := r.rule.Attr("embed").(*bf.ListExpr); ok {
			for _, embedElem := range embedList.List {
				embedStr, ok := embedElem.(*bf.StringExpr)
				if !ok {
					continue
				}
				embedLabel, err := ParseLabel(embedStr.Value)
				if err != nil {
					continue
				}
				embedLabels = append(embedLabels, embedLabel)
			}
		}
		if libraryStr, ok := r.rule.Attr("library").(*bf.StringExpr); ok {
			if libraryLabel, err := ParseLabel(libraryStr.Value); err == nil {
				embedLabels = append(embedLabels, libraryLabel)
			}
		}

		for _, l := range embedLabels {
			embed, ok := ix.findRuleByLabel(l, r.label.Pkg)
			if !ok {
				continue
			}
			if embed.rule.AttrString("importpath") != importpath {
				continue
			}
			embed.embedded = true
		}
	}
}

// buildImportIndex constructs the map used by findRuleByImport.
func (ix *RuleIndex) buildImportIndex() {
	ix.importMap = make(map[importSpec][]*ruleRecord)
	for _, r := range ix.rules {
		if isGoProtoLibrary(r.rule.Kind()) {
			protoImports := findGoProtoSources(ix, r)
			r.importedAs = append(r.importedAs, protoImports...)
		}
		for _, imp := range r.importedAs {
			if imp.lang == config.GoLang && r.embedded {
				continue
			}
			ix.importMap[imp] = append(ix.importMap[imp], r)
		}
	}
}

type ruleNotFoundError struct {
	imp     string
	fromRel string
}

func (e ruleNotFoundError) Error() string {
	return fmt.Sprintf("no rule found for import %q, needed in package %q", e.imp, e.fromRel)
}

func (ix *RuleIndex) findRuleByLabel(label Label, fromRel string) (*ruleRecord, bool) {
	label = label.Abs("", fromRel)
	r, ok := ix.labelMap[label]
	return r, ok
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
// import, this function will attempt to choose one based on Go vendoring logic.
// In ambiguous cases, an error is returned.
func (ix *RuleIndex) findRuleByImport(imp importSpec, lang config.Language, fromRel string) (*ruleRecord, error) {
	matches := ix.importMap[imp]
	var bestMatch *ruleRecord
	var bestMatchIsVendored bool
	var bestMatchVendorRoot string
	var matchError error
	for _, m := range matches {
		if m.lang != lang {
			continue
		}

		switch imp.lang {
		case config.GoLang:
			// Apply vendoring logic for Go libraries. A library in a vendor directory
			// is only visible in the parent tree. Vendored libraries supercede
			// non-vendored libraries, and libraries closer to fromRel supercede
			// those further up the tree.
			isVendored := false
			vendorRoot := ""
			if m.label.Repo == "" {
				parts := strings.Split(m.label.Pkg, "/")
				for i, part := range parts {
					if part == "vendor" {
						isVendored = true
						vendorRoot = strings.Join(parts[:i], "/")
						break
					}
				}
			}
			if isVendored && fromRel != vendorRoot && !strings.HasPrefix(fromRel, vendorRoot+"/") {
				// vendor directory not visible
				continue
			}
			if bestMatch == nil || isVendored && (!bestMatchIsVendored || len(vendorRoot) > len(bestMatchVendorRoot)) {
				// Current match is better
				bestMatch = m
				bestMatchIsVendored = isVendored
				bestMatchVendorRoot = vendorRoot
				matchError = nil
			} else if !isVendored && (bestMatchIsVendored || len(vendorRoot) < len(bestMatchVendorRoot)) {
				// Current match is worse
			} else {
				// Match is ambiguous
				matchError = fmt.Errorf("multiple rules (%s and %s) may be imported with %q", bestMatch.label, m.label, imp.imp)
			}

		default:
			if bestMatch == nil {
				bestMatch = m
			} else {
				matchError = fmt.Errorf("multiple rules (%s and %s) may be imported with %q", bestMatch.label, m.label, imp.imp)
			}
		}
	}
	if matchError != nil {
		return nil, matchError
	}
	if bestMatch == nil {
		return nil, ruleNotFoundError{imp.imp, fromRel}
	}

	if imp.lang == config.ProtoLang && lang == config.GoLang {
		importpath := bestMatch.rule.AttrString("importpath")
		if betterMatch, err := ix.findRuleByImport(importSpec{config.GoLang, importpath}, config.GoLang, fromRel); err == nil {
			return betterMatch, nil
		}
	}

	return bestMatch, nil
}

func (ix *RuleIndex) findLabelByImport(imp importSpec, lang config.Language, fromRel string) (Label, error) {
	r, err := ix.findRuleByImport(imp, lang, fromRel)
	if err != nil {
		return NoLabel, err
	}
	return r.label, nil
}

func findGoProtoSources(ix *RuleIndex, r *ruleRecord) []importSpec {
	protoLabel, err := ParseLabel(r.rule.AttrString("proto"))
	if err != nil {
		return nil
	}
	proto, ok := ix.findRuleByLabel(protoLabel, r.label.Pkg)
	if !ok {
		return nil
	}
	var importedAs []importSpec
	for _, source := range findSources(proto.rule, proto.label.Pkg, ".proto") {
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

func isGoLibrary(kind string) bool {
	return kind == "go_library" || isGoProtoLibrary(kind)
}

func isGoProtoLibrary(kind string) bool {
	return kind == "go_proto_library" || kind == "go_grpc_library"
}
