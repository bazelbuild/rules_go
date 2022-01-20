package main

import (
	"fmt"
	"testing"

	bzl "github.com/bazelbuild/buildtools/build"
)

func TestPatchItemParser_Success(t *testing.T) {
	tests := []struct {
		expression []byte
		result     string
	}{
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			Label("//third_party:org_golang_x_tools-gazelle.patch")`),
			result: "//third_party:org_golang_x_tools-gazelle.patch",
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			"@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch"`),
			result: "//third_party:org_golang_x_tools-gazelle.patch",
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			"//third_party:org_golang_x_tools-gazelle.patch"`),
			result: "//third_party:org_golang_x_tools-gazelle.patch",
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			Label("@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch")`),
			result: "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
		},
	}

	for _, tt := range tests {
		t.Run(fmt.Sprintf("%v", tt.expression), func(t *testing.T) {
			patchExpr, err := bzl.Parse("repos.bzl", tt.expression)
			if err != nil {
				t.Fatalf(err.Error())
			}

			patchLabelStr, _, err := parsePatchesItem(patchExpr.Stmt[0])
			if err != nil {
				t.Errorf("unexpected error while parsing expression: %q", err.Error())
			} else if patchLabelStr != tt.result {
				t.Errorf("expected result %q, but got result %q instead", tt.result, patchLabelStr)
			}
		})
	}
}

func TestPatchItemParser_Error(t *testing.T) {
	tests := []struct {
		expression []byte
		error      string
	}{
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			NotLabel("//third_party:org_golang_x_tools-gazelle.patch")`),
			error: `invalid patch function: "NotLabel"`,
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			NotLabel(True)`),
			error: `invalid patch function: "NotLabel"`,
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			True`),
			error: "not all patches are string literals or Label()",
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			Label("//third_party:org_golang_x_tools-gazelle.patch", True)`),
			error: "Label expr should have 1 argument, found 2",
		},
		{
			expression: []byte(`# releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
			Label(True)`),
			error: "Label expr does not contain a string literal",
		},
	}

	for _, tt := range tests {
		t.Run(fmt.Sprintf("%v", tt.expression), func(t *testing.T) {
			patchExpr, err := bzl.Parse("repos.bzl", tt.expression)
			if err != nil {
				t.Fatalf(err.Error())
			}

			patchLabelStr, _, err := parsePatchesItem(patchExpr.Stmt[0])

			if err == nil {
				t.Errorf("expected error %q, but got result %q instead", tt.error, patchLabelStr)
			} else if err.Error() != tt.error {
				t.Errorf("expected error %q, but got error %q instead", tt.error, err.Error())
			}
		})
	}
}
