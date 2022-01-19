package main

import (
	"fmt"
	"io/ioutil"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
)

const (
	reposFile = "testdata/repositories.bzl"
	funcName  = "go_rules_dependencies"
)

func TestPatchItemParser(t *testing.T) {
	rules, err := loadRepositoriesFile(reposFile)
	if err != nil {
		t.Fatal(err)
	}
	// Loop over the repo rules
	for _, expr := range rules {
		patches, expected, err := parseRepoRule(expr)
		if err != nil {
			t.Fatal(err)
		}
		// parse each of the patch items, check against expected result
		for i, patchLabelExpr := range patches.List {
			patchLabelStr, _, err := parsePatchesItem(patchLabelExpr)
			if err != nil && err.Error() != expected[i] {
				t.Fatalf("Patch index %d: expected %s but got error: %s", i, expected[i], err.Error())
			}
			if err == nil && patchLabelStr != expected[i] {
				t.Fatalf("Patch index %d: expected %s but got: %s", i, expected[i], patchLabelStr)
			}
		}
	}
}

// loads the repository file and parses out the body
func loadRepositoriesFile(filename string) (body []bzl.Expr, err error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("could not open %s: %s\n", filename, err)
	}

	parsed, err := bzl.Parse(filename, data)
	if err != nil {
		return nil, fmt.Errorf("failed to parse: %s\n", err)
	}

	// Parse out go_rules_dependencies
	for _, expr := range parsed.Stmt {
		def, ok := expr.(*bzl.DefStmt)
		if !ok {
			continue
		}
		if def.Name == funcName {
			body = def.Body
			break
		}
	}

	return
}

// parses an individual repo rule
func parseRepoRule(expr bzl.Expr) (patches *bzl.ListExpr, expected []string, err error) {
	// Check if repo rule is a function call
	call, ok := expr.(*bzl.CallExpr)
	if !ok {
		return nil, nil, fmt.Errorf("repo_rule is not a CallExpr")
	}

	expected = make([]string, 0, 5)

	// Loop over the KV pairs in the repo_rule to parse patches and expected results
	for _, arg := range call.List {
		kwarg, ok := arg.(*bzl.AssignExpr)
		if !ok {
			continue
		}

		key, ok := kwarg.LHS.(*bzl.Ident) // required by parser
		if !ok {
			continue
		}
		// Fetch each of the expected items and store them
		if key.Name == "expected" {
			value, ok := kwarg.RHS.(*bzl.ListExpr)
			if !ok {
				return nil, nil, fmt.Errorf("expected value does not contain a List at line %d\n", kwarg.OpPos.Line)
			}

			for _, val := range value.List {
				str, ok := val.(*bzl.StringExpr)

				if !ok {
					return nil, nil, fmt.Errorf("invalid expected results at line %d\n", kwarg.OpPos.Line)
				}

				expected = append(expected, str.Value)
			}
		}

		// Parse the patches list
		if key.Name == "patches" {
			value, ok := kwarg.RHS.(*bzl.ListExpr)
			if !ok {
				return nil, nil, fmt.Errorf("patches do not contain a List at line %d\n", kwarg.OpPos.Line)
			}

			patches = value
		}
	}

	return
}
