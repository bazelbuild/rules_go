package gopackagesdriver_test

import (
	"encoding/json"
	"fmt"
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
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "hello",
    srcs = ["hello.go"],
    importpath = "example.com/hello",
    visibility = ["//visibility:public"],
)

-- hello.go --
package hello

import "os"

func main() {
	fmt.Fprintln(os.Stderr, "Hello World!")
}
		`,
	})
}

const (
	osPkgID = "@io_bazel_rules_go//stdlib:os"
)

func TestBaseFileLookup(t *testing.T) {
	reader := strings.NewReader("{}")
	out, err := bazel_testing.BazelOutputWithInput(reader, "run", "@io_bazel_rules_go//go/tools/gopackagesdriver", "--", "file=hello.go")
	if err != nil {
		t.Errorf("Unexpected error: %w", err.Error())
	}
	fmt.Println(string(out))
	var resp response
	err = json.Unmarshal(out, &resp)
	if err != nil {
		t.Errorf("Failed to unmarshal packages driver response: %w\n%w", err.Error(), out)
	}

	t.Run("roots", func(t *testing.T) {
		if len(resp.Roots) != 1 {
			t.Errorf("Excpected 1 package root: %+v", resp.Roots)
		}

		if resp.Roots[0] != "@//:hello" {
			t.Errorf("Unecpected package id: %q", resp.Roots[0])
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
		}

		if len(pkg.CompiledGoFiles) != 1 || len(pkg.GoFiles) != 1 ||
			path.Base(pkg.GoFiles[0]) != "hello.go" || path.Base(pkg.CompiledGoFiles[0]) != "hello.go" {
			t.Errorf("Expected to find 1 file (hello.go) in (Compiled)GoFiles:\n%+v", pkg)
		}

		if pkg.Standard {
			t.Errorf("Expected package to not be Standard:\n%+v", pkg)
		}

		if len(pkg.Imports) != 1 {
			t.Errorf("Expected one import:\n%+v", pkg)
		}

		if pkg.Imports["os"] != osPkgID {
			t.Errorf("Expected os import to map to %q:\n%+v", osPkgID, pkg)
		}
	})

	t.Run("dependency", func(t *testing.T) {
		var osPkg *gpd.FlatPackage
		for _, p := range resp.Packages {
			if p.ID == osPkgID {
				osPkg = p
			}
		}

		if osPkg == nil {
			t.Errorf("Expected os package to be included:\n%+v", osPkg)
		}

		if !osPkg.Standard {
			t.Errorf("Expected os import to be standard:\n%+v", osPkg)
		}
	})
}
