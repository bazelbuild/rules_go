package gopackagesdriver_test

import (
	"encoding/json"
	"path"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
	gpd "github.com/bazelbuild/rules_go/go/tools/gopackagesdriver"
)

type response struct {
	Roots    []string `json:",omitempty"`
	Packages []*gpd.FlatPackage
}

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "hello",
    srcs = ["hello.go"],
    importpath = "example.com/hello",
    visibility = ["//visibility:public"],
)

go_test(
	name = "hello_test",
	srcs = [
		"hello_test.go",
		"hello_external_test.go",
	],
	embed = [":hello"],
)

-- hello.go --
package hello

import "os"

func main() {
	fmt.Fprintln(os.Stderr, "Hello World!")
}

-- hello_test.go --
package hello

import "testing"

func TestHelloInternal(t *testing.T) {}

-- hello_external_test.go --
package hello_test

import "testing"

func TestHelloExternal(t *testing.T) {}
		`,
	})
}

const (
	osPkgID       = "@io_bazel_rules_go//stdlib:os"
	bzlmodOsPkgID = "@@io_bazel_rules_go//stdlib:os"
)

func TestBaseFileLookup(t *testing.T) {
	reader := strings.NewReader("{}")
	out, _, err := bazel_testing.BazelOutputWithInput(reader, "run", "@io_bazel_rules_go//go/tools/gopackagesdriver", "--", "file=hello.go")
	if err != nil {
		t.Errorf("Unexpected error: %w", err.Error())
		return
	}
	var resp response
	err = json.Unmarshal(out, &resp)
	if err != nil {
		t.Errorf("Failed to unmarshal packages driver response: %w\n%w", err.Error(), out)
		return
	}

	t.Run("roots", func(t *testing.T) {
		if len(resp.Roots) != 1 {
			t.Errorf("Expected 1 package root: %+v", resp.Roots)
			return
		}

		if !strings.HasSuffix(resp.Roots[0], "//:hello") {
			t.Errorf("Unexpected package id: %q", resp.Roots[0])
			return
		}
	})

	t.Run("package", func(t *testing.T) {
		var pkg *gpd.FlatPackage
		for _, p := range resp.Packages {
			if p.ID == resp.Roots[0] {
				pkg = p
			}
		}

		if pkg == nil {
			t.Errorf("Expected to find %q in resp.Packages", resp.Roots[0])
			return
		}

		if len(pkg.CompiledGoFiles) != 1 || len(pkg.GoFiles) != 1 ||
			path.Base(pkg.GoFiles[0]) != "hello.go" || path.Base(pkg.CompiledGoFiles[0]) != "hello.go" {
			t.Errorf("Expected to find 1 file (hello.go) in (Compiled)GoFiles:\n%+v", pkg)
			return
		}

		if pkg.Standard {
			t.Errorf("Expected package to not be Standard:\n%+v", pkg)
			return
		}

		if len(pkg.Imports) != 1 {
			t.Errorf("Expected one import:\n%+v", pkg)
			return
		}

		if pkg.Imports["os"] != osPkgID && pkg.Imports["os"] != bzlmodOsPkgID {
			t.Errorf("Expected os import to map to %q or %q:\n%+v", osPkgID, bzlmodOsPkgID, pkg)
			return
		}
	})

	t.Run("dependency", func(t *testing.T) {
		var osPkg *gpd.FlatPackage
		for _, p := range resp.Packages {
			if p.ID == osPkgID || p.ID == bzlmodOsPkgID {
				osPkg = p
			}
		}

		if osPkg == nil {
			t.Errorf("Expected os package to be included:\n%+v", osPkg)
			return
		}

		if !osPkg.Standard {
			t.Errorf("Expected os import to be standard:\n%+v", osPkg)
			return
		}
	})
}

func TestExternalTests(t *testing.T) {
	reader := strings.NewReader("{}")
	out, stderr, err := bazel_testing.BazelOutputWithInput(reader, "run", "@io_bazel_rules_go//go/tools/gopackagesdriver", "--", "file=hello_external_test.go")
	if err != nil {
		t.Errorf("Unexpected error: %w\n=====\n%s\n=====", err.Error(), stderr)
	}
	var resp response
	err = json.Unmarshal(out, &resp)
	if err != nil {
		t.Errorf("Failed to unmarshal packages driver response: %w\n%w", err.Error(), out)
	}

	if len(resp.Roots) != 2 {
		t.Errorf("Expected exactly two roots for package: %+v", resp.Roots)
	}

	var testId, xTestId string
	for _, id := range resp.Roots {
		if strings.HasSuffix(id, "_xtest") {
			xTestId = id
		} else {
			testId = id
		}
	}

	for _, p := range resp.Packages {
		if p.ID == xTestId {
			if !strings.HasSuffix(p.PkgPath, "_test") {
				t.Errorf("PkgPath missing _test suffix")
			}
			assertSuffixesInList(t, p.GoFiles, "/hello_external_test.go")
		} else if p.ID == testId {
			assertSuffixesInList(t, p.GoFiles, "/hello.go", "/hello_test.go")
		}
	}
}

func assertSuffixesInList(t *testing.T, list []string, expectedSuffixes ...string) {
	for _, suffix := range expectedSuffixes {
		itemFound := false
		for _, listItem := range list {
			itemFound = itemFound || strings.HasSuffix(listItem, suffix)
		}

		if !itemFound {
			t.Errorf("Expected suffix %q in list, but was not found: %+v", suffix, list)
		}
	}
}
