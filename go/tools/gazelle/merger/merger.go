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

// Package merger provides methods for merging parsed BUILD files.
package merger

import (
	"fmt"
	"log"
	"sort"
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
)

const (
	gazelleIgnore = "# gazelle:ignore" // marker in a BUILD file to ignore it.
	keep          = "# keep"           // marker in srcs or deps to tell gazelle to preserve.
)

var (
	mergeableFields = map[string]bool{
		"srcs":    true,
		"deps":    true,
		"library": true,
	}
)

// MergeWithExisting merges "genFile" with "oldFile" and returns the
// merged file.
//
// "genFile" is a file generated by Gazelle. It must not be nil.
// "oldFile" is the existing file. It may be nil if no file was found.
//
// If "oldFile" is nil, "genFile" will be returned. If "oldFile" contains
// a "# gazelle:ignore" comment, nil will be returned. If an error occurs,
// it will be logged, and nil will be returned.
func MergeWithExisting(genFile, oldFile *bf.File) *bf.File {
	if oldFile == nil {
		return genFile
	}
	if shouldIgnore(oldFile) {
		return nil
	}

	mergedFile := *oldFile
	mergedFile.Stmt = make([]bf.Expr, len(oldFile.Stmt))
	for i := range oldFile.Stmt {
		mergedFile.Stmt[i] = oldFile.Stmt[i]
	}

	var newStmt []bf.Expr
	for _, s := range genFile.Stmt {
		genRule, ok := s.(*bf.CallExpr)
		if !ok {
			log.Panicf("got %v expected only CallExpr in %q", s, genFile.Path)
		}
		i, oldRule := match(&mergedFile, genRule)
		if oldRule == nil {
			newStmt = append(newStmt, genRule)
			continue
		}

		var mergedRule bf.Expr
		if kind(oldRule) == "load" {
			mergedRule = mergeLoad(genRule, oldRule, oldFile)
		} else {
			mergedRule = mergeRule(genRule, oldRule)
		}
		mergedFile.Stmt[i] = mergedRule
	}

	mergedFile.Stmt = append(mergedFile.Stmt, newStmt...)
	return &mergedFile
}

// merge combines information from gen and old and returns an updated rule.
// Both rules must be non-nil and must have the same kind and same name.
func mergeRule(gen, old *bf.CallExpr) *bf.CallExpr {
	genRule := bf.Rule{Call: gen}
	oldRule := bf.Rule{Call: old}
	merged := *old
	merged.List = nil
	mergedRule := bf.Rule{Call: &merged}

	// Copy unnamed arguments from the old rule without merging. The only rule
	// generated with unnamed arguments is go_prefix, which we currently
	// leave in place.
	// TODO: maybe gazelle should allow the prefix to be changed.
	for _, a := range old.List {
		if b, ok := a.(*bf.BinaryExpr); ok && b.Op == "=" {
			break
		}
		merged.List = append(merged.List, a)
	}

	// Merge attributes from the old rule. Preserve comments on old attributes.
	// Assume generated attributes have no comments.
	for _, k := range oldRule.AttrKeys() {
		oldAttr := oldRule.AttrDefn(k)
		if !mergeableFields[k] {
			merged.List = append(merged.List, oldAttr)
			continue
		}

		oldExpr := oldAttr.Y
		genExpr := genRule.Attr(k)
		mergedExpr, err := mergeExpr(genExpr, oldExpr)
		if err != nil {
			// TODO: add a verbose mode and log errors like this.
			mergedExpr = genExpr
		}
		if mergedExpr != nil {
			mergedAttr := *oldAttr
			mergedAttr.Y = mergedExpr
			merged.List = append(merged.List, &mergedAttr)
		}
	}

	// Merge attributes from genRule that we haven't processed already.
	for _, k := range genRule.AttrKeys() {
		if mergedRule.Attr(k) == nil {
			mergedRule.SetAttr(k, genRule.Attr(k))
		}
	}

	return &merged
}

// mergeExpr combines information from gen and old and returns an updated
// expression. The following kinds of expressions are recognized:
//
//   * nil
//   * strings (can only be merged with strings)
//   * lists of strings
//   * a call to select with a dict argument. The dict keys must be strings,
//     and the values must be lists of strings.
//   * a list of strings combined with a select call using +. The list must
//     be the left operand.
//
// An error is returned if the expressions can't be merged, for example
// because they are not in one of the above formats.
func mergeExpr(gen, old bf.Expr) (bf.Expr, error) {
	if _, ok := gen.(*bf.StringExpr); ok {
		if shouldKeep(old) {
			return old, nil
		}
		return gen, nil
	}

	genList, genDict, err := exprListAndDict(gen)
	if err != nil {
		return nil, err
	}
	oldList, oldDict, err := exprListAndDict(old)
	if err != nil {
		return nil, err
	}

	mergedList := mergeList(genList, oldList)
	mergedDict, err := mergeDict(genDict, oldDict)
	if err != nil {
		return nil, err
	}

	var mergedSelect bf.Expr
	if mergedDict != nil {
		mergedSelect = &bf.CallExpr{
			X:    &bf.LiteralExpr{Token: "select"},
			List: []bf.Expr{mergedDict},
		}
	}

	if mergedList == nil {
		return mergedSelect, nil
	}
	if mergedSelect == nil {
		return mergedList, nil
	}
	mergedList.ForceMultiLine = true
	return &bf.BinaryExpr{
		X:  mergedList,
		Op: "+",
		Y:  mergedSelect,
	}, nil
}

// exprListAndDict matches an expression and attempts to extract either a list
// of expressions, a call to select with a dictionary, or both.
// An error is returned if the expression could not be matched.
func exprListAndDict(expr bf.Expr) (*bf.ListExpr, *bf.DictExpr, error) {
	if expr == nil {
		return nil, nil, nil
	}
	switch expr := expr.(type) {
	case *bf.ListExpr:
		return expr, nil, nil
	case *bf.CallExpr:
		if x, ok := expr.X.(*bf.LiteralExpr); ok && x.Token == "select" && len(expr.List) == 1 {
			if d, ok := expr.List[0].(*bf.DictExpr); ok {
				return nil, d, nil
			}
		}
	case *bf.BinaryExpr:
		if expr.Op != "+" {
			return nil, nil, fmt.Errorf("expression could not be matched: unknown operator: %s", expr.Op)
		}
		l, ok := expr.X.(*bf.ListExpr)
		if !ok {
			return nil, nil, fmt.Errorf("expression could not be matched: left operand not a list")
		}
		call, ok := expr.Y.(*bf.CallExpr)
		if !ok || len(call.List) != 1 {
			return nil, nil, fmt.Errorf("expression could not be matched: right operand not a call with one argument")
		}
		x, ok := call.X.(*bf.LiteralExpr)
		if !ok || x.Token != "select" {
			return nil, nil, fmt.Errorf("expression could not be matched: right operand not a call to select")
		}
		d, ok := call.List[0].(*bf.DictExpr)
		if !ok {
			return nil, nil, fmt.Errorf("expression could not be matched: argument to right operand not a dict")
		}
		return l, d, nil
	}
	return nil, nil, fmt.Errorf("expression could not be matched")
}

func mergeList(gen, old *bf.ListExpr) *bf.ListExpr {
	if old == nil {
		return gen
	}
	if gen == nil {
		gen = &bf.ListExpr{List: []bf.Expr{}}
	}

	// Build a list of strings from the gen list and keep matching strings
	// in the old list. This preserves comments. Also keep anything with
	// a "# keep" comment, whether or not it's in the gen list.
	genSet := make(map[string]bool)
	for _, v := range gen.List {
		if s := stringValue(v); s != "" {
			genSet[s] = true
		}
	}

	var merged []bf.Expr
	kept := make(map[string]bool)
	for _, v := range old.List {
		s := stringValue(v)
		if shouldKeep(v) || genSet[s] {
			merged = append(merged, v)
			if s != "" {
				kept[s] = true
			}
		}
	}

	// Add anything in the gen list that wasn't kept.
	for _, v := range gen.List {
		if s := stringValue(v); kept[s] {
			continue
		}
		merged = append(merged, v)
	}

	if len(merged) == 0 {
		return nil
	}
	return &bf.ListExpr{List: merged}
}

func mergeDict(gen, old *bf.DictExpr) (*bf.DictExpr, error) {
	if old == nil {
		return gen, nil
	}
	if gen == nil {
		gen = &bf.DictExpr{List: []bf.Expr{}}
	}

	var entries []*dictEntry
	entryMap := make(map[string]*dictEntry)

	for _, kv := range old.List {
		k, v, err := dictEntryKeyValue(kv)
		if err != nil {
			return nil, err
		}
		if _, ok := entryMap[k]; ok {
			return nil, fmt.Errorf("old dict contains more than one case named %q", k)
		}
		e := &dictEntry{key: k, oldValue: v}
		entries = append(entries, e)
		entryMap[k] = e
	}

	for _, kv := range gen.List {
		k, v, err := dictEntryKeyValue(kv)
		if err != nil {
			return nil, err
		}
		e, ok := entryMap[k]
		if !ok {
			e = &dictEntry{key: k}
			entries = append(entries, e)
			entryMap[k] = e
		}
		e.genValue = v
	}

	keys := make([]string, 0, len(entries))
	haveDefault := false
	for _, e := range entries {
		e.mergedValue = mergeList(e.genValue, e.oldValue)
		if e.key == "//conditions:default" {
			// Keep the default case, even if it's empty.
			haveDefault = true
			if e.mergedValue == nil {
				e.mergedValue = &bf.ListExpr{}
			}
		} else if e.mergedValue != nil {
			keys = append(keys, e.key)
		}
	}
	if len(keys) == 0 && (!haveDefault || len(entryMap["//conditions:default"].mergedValue.List) == 0) {
		return nil, nil
	}
	sort.Strings(keys)
	// Always put the default case last.
	if haveDefault {
		keys = append(keys, "//conditions:default")
	}

	mergedEntries := make([]bf.Expr, len(keys))
	for i, k := range keys {
		e := entryMap[k]
		mergedEntries[i] = &bf.KeyValueExpr{
			Key:   &bf.StringExpr{Value: e.key},
			Value: e.mergedValue,
		}
	}

	return &bf.DictExpr{List: mergedEntries, ForceMultiLine: true}, nil
}

type dictEntry struct {
	key                             string
	oldValue, genValue, mergedValue *bf.ListExpr
}

func dictEntryKeyValue(e bf.Expr) (string, *bf.ListExpr, error) {
	kv, ok := e.(*bf.KeyValueExpr)
	if !ok {
		return "", nil, fmt.Errorf("dict entry was not a key-value pair: %#v", e)
	}
	k, ok := kv.Key.(*bf.StringExpr)
	if !ok {
		return "", nil, fmt.Errorf("dict key was not string: %#v", kv.Key)
	}
	v, ok := kv.Value.(*bf.ListExpr)
	if !ok {
		return "", nil, fmt.Errorf("dict value was not list: %#v", kv.Value)
	}
	return k.Value, v, nil
}

func mergeLoad(gen, old *bf.CallExpr, oldfile *bf.File) *bf.CallExpr {
	vals := make(map[string]bf.Expr)
	for _, v := range gen.List[1:] {
		vals[stringValue(v)] = v
	}
	for _, v := range old.List[1:] {
		rule := stringValue(v)
		if _, ok := vals[rule]; !ok && ruleUsed(rule, oldfile) {
			vals[rule] = v
		}
	}
	keys := make([]string, 0, len(vals))
	for k := range vals {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	merged := *old
	merged.List = old.List[:1]
	for _, k := range keys {
		merged.List = append(merged.List, vals[k])
	}
	return &merged
}

// shouldIgnore checks whether "gazelle:ignore" appears at the beginning of
// a comment before or after any top-level statement in the file.
func shouldIgnore(oldFile *bf.File) bool {
	for _, s := range oldFile.Stmt {
		for _, c := range s.Comment().After {
			if strings.HasPrefix(c.Token, gazelleIgnore) {
				return true
			}
		}
		for _, c := range s.Comment().Before {
			if strings.HasPrefix(c.Token, gazelleIgnore) {
				return true
			}
		}
	}
	return false
}

// shouldKeep returns whether an expression from the original file should be
// preserved. This is true if it has a trailing comment that starts with "keep".
func shouldKeep(e bf.Expr) bool {
	c := e.Comment()
	return len(c.Suffix) > 0 && strings.HasPrefix(c.Suffix[0].Token, keep)
}

func ruleUsed(rule string, oldfile *bf.File) bool {
	return len(oldfile.Rules(rule)) != 0
}

// match looks for the matching CallExpr in f using X and name
// i.e. two 'go_library(name = "foo", ...)' are considered matches
// despite the values of the other fields.
// exception: if c is a 'load' statement, the match is done on the first value.
func match(f *bf.File, c *bf.CallExpr) (int, *bf.CallExpr) {
	var m matcher
	if kind := kind(c); kind == "load" {
		if len(c.List) == 0 {
			return -1, nil
		}
		m = &loadMatcher{stringValue(c.List[0])}
	} else {
		m = &nameMatcher{kind, name(c)}
	}
	for i, s := range f.Stmt {
		other, ok := s.(*bf.CallExpr)
		if !ok {
			continue
		}
		if m.match(other) {
			return i, other
		}
	}
	return -1, nil
}

type matcher interface {
	match(c *bf.CallExpr) bool
}

type nameMatcher struct {
	kind, name string
}

func (m *nameMatcher) match(c *bf.CallExpr) bool {
	return m.kind == kind(c) && m.name == name(c)
}

type loadMatcher struct {
	load string
}

func (m *loadMatcher) match(c *bf.CallExpr) bool {
	return kind(c) == "load" && len(c.List) > 0 && m.load == stringValue(c.List[0])
}

func kind(c *bf.CallExpr) string {
	return (&bf.Rule{c}).Kind()
}

func name(c *bf.CallExpr) string {
	return (&bf.Rule{c}).Name()
}

func stringValue(e bf.Expr) string {
	s, ok := e.(*bf.StringExpr)
	if !ok {
		return ""
	}
	return s.Value
}
