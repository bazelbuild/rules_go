// Copyright 2021 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"go/build"
	"os"
	"path/filepath"
	"strings"
)

// Copy and pasted from golang.org/x/tools/go/packages
type flatPackagesError struct {
	Pos  string // "file:line:col" or "file:line" or "" or "-"
	Msg  string
	Kind flatPackagesErrorKind
}

type flatPackagesErrorKind int

const (
	UnknownError flatPackagesErrorKind = iota
	ListError
	ParseError
	TypeError
)

func (err flatPackagesError) Error() string {
	pos := err.Pos
	if pos == "" {
		pos = "-" // like token.Position{}.String()
	}
	return pos + ": " + err.Msg
}

// flatPackage is the JSON form of Package
// It drops all the type and syntax fields, and transforms the Imports
type flatPackage struct {
	ID              string
	Name            string              `json:",omitempty"`
	PkgPath         string              `json:",omitempty"`
	Standard        bool                `json:",omitempty"`
	Errors          []flatPackagesError `json:",omitempty"`
	GoFiles         []string            `json:",omitempty"`
	CompiledGoFiles []string            `json:",omitempty"`
	OtherFiles      []string            `json:",omitempty"`
	ExportFile      string              `json:",omitempty"`
	Imports         map[string]string   `json:",omitempty"`
}

type goListPackage struct {
	Dir        string // directory containing package sources
	ImportPath string // import path of package in dir
	Name       string // package name
	Target     string // install path
	Goroot     bool   // is this package in the Go root?
	Standard   bool   // is this package part of the standard Go library?
	Root       string // Go root or Go path dir containing this package
	Export     string // file containing export data (when using -export)
	// Source files
	GoFiles           []string // .go source files (excluding CgoFiles, TestGoFiles, XTestGoFiles)
	CgoFiles          []string // .go source files that import "C"
	CompiledGoFiles   []string // .go files presented to compiler (when using -compiled)
	IgnoredGoFiles    []string // .go source files ignored due to build constraints
	IgnoredOtherFiles []string // non-.go source files ignored due to build constraints
	CFiles            []string // .c source files
	CXXFiles          []string // .cc, .cxx and .cpp source files
	MFiles            []string // .m source files
	HFiles            []string // .h, .hh, .hpp and .hxx source files
	FFiles            []string // .f, .F, .for and .f90 Fortran source files
	SFiles            []string // .s source files
	SwigFiles         []string // .swig files
	SwigCXXFiles      []string // .swigcxx files
	SysoFiles         []string // .syso object files to add to archive
	TestGoFiles       []string // _test.go files in package
	XTestGoFiles      []string // _test.go files outside package
	// Embedded files
	EmbedPatterns      []string // //go:embed patterns
	EmbedFiles         []string // files matched by EmbedPatterns
	TestEmbedPatterns  []string // //go:embed patterns in TestGoFiles
	TestEmbedFiles     []string // files matched by TestEmbedPatterns
	XTestEmbedPatterns []string // //go:embed patterns in XTestGoFiles
	XTestEmbedFiles    []string // files matched by XTestEmbedPatterns
	// Dependency information
	Imports   []string          // import paths used by this package
	ImportMap map[string]string // map from source import to ImportPath (identity entries omitted)
	// Error information
	Incomplete bool                 // this package or a dependency has an error
	Error      *flatPackagesError   // error loading package
	DepsErrors []*flatPackagesError // errors loading dependencies
}

func stdlibPackageID(importPath string) string {
	return "@io_bazel_rules_go//stdlib:" + importPath
}

func execRootPath(execRoot, p string) string {
	dir, _ := filepath.Rel(execRoot, p)
	return filepath.Join("__BAZEL_OUTPUT_BASE__", dir)
}

func absoluteSourcesPaths(execRoot, pkgDir string, srcs []string) []string {
	ret := make([]string, 0, len(srcs))
	pkgDir = execRootPath(execRoot, pkgDir)
	for _, src := range srcs {
		ret = append(ret, filepath.Join(pkgDir, src))
	}
	return ret
}

func flatPackageForStd(execRoot string, pkg *goListPackage) *flatPackage {
	// Don't use generated files from the stdlib
	goFiles := absoluteSourcesPaths(execRoot, pkg.Dir, pkg.GoFiles)

	newPkg := &flatPackage{
		ID:              stdlibPackageID(pkg.ImportPath),
		Name:            pkg.Name,
		PkgPath:         pkg.ImportPath,
		ExportFile:      execRootPath(execRoot, pkg.Target),
		Imports:         map[string]string{},
		Standard:        pkg.Standard,
		GoFiles:         goFiles,
		CompiledGoFiles: goFiles,
	}
	for _, imp := range pkg.Imports {
		newPkg.Imports[imp] = stdlibPackageID(imp)
	}
	// We don't support CGo for now
	delete(newPkg.Imports, "C")
	return newPkg
}

// In Go 1.18, the standard library started using go:embed directives.
// When Bazel runs this action, it does so inside a sandbox where GOROOT points
// to an external/go_sdk directory that contains a symlink farm of all files in
// the Go SDK.
// If we run "go list" with that GOROOT, this action will fail because those
// go:embed directives will refuse to include the symlinks in the sandbox.
//
// To work around this, cloneRoot creates a copy of external/go_sdk into a new
// directory "root" while retaining its path relative to the root directory.
// So "$OUTPUT_BASE/external/go_sdk" becomes
// "$OUTPUT_BASE/root/external/go_sdk".
// This ensures that file paths in the generated JSON are still valid.
//
// cloneRoot returns the new root directory and the new GOROOT we should run
// under.
func cloneRoot(execRoot, goroot string) (newRoot string, newGoroot string, err error) {
	relativeGoroot, err := filepath.Rel(abs(execRoot), abs(goroot))
	if err != nil {
		// GOROOT has to be a subdirectory of execRoot.
		// Otherwise we're breaking the sandbox.
		return "", "", fmt.Errorf("GOROOT %q is not relative to execution root %q: %v", goroot, execRoot)
	}

	newRoot = filepath.Join(execRoot, "root")
	newGoroot = filepath.Join(newRoot, relativeGoroot)
	if err := os.MkdirAll(newGoroot, 01755); err != nil {
		return "", "", err
	}

	if err := replicate(goroot, newGoroot, replicatePaths("src", "pkg/tool", "pkg/include")); err != nil {
		return "", "", err
	}

	return newRoot, newGoroot, nil
}

// stdliblist runs `go list -json` on the standard library and saves it to a file.
func stdliblist(args []string) error {
	// process the args
	flags := flag.NewFlagSet("stdliblist", flag.ExitOnError)
	goenv := envFlags(flags)
	out := flags.String("out", "", "Path to output go list json")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}

	execRoot, goroot, err := cloneRoot(".", os.Getenv("GOROOT"))
	if err != nil {
		return err
	}

	// Ensure paths are absolute.
	absPaths := []string{}
	for _, path := range filepath.SplitList(os.Getenv("PATH")) {
		absPaths = append(absPaths, abs(path))
	}
	os.Setenv("PATH", strings.Join(absPaths, string(os.PathListSeparator)))
	os.Setenv("GOROOT", goroot)
	// Make sure we have an absolute path to the C compiler.
	// TODO(#1357): also take absolute paths of includes and other paths in flags.
	os.Setenv("CC", abs(os.Getenv("CC")))

	cachePath := abs(*out + ".gocache")
	defer os.RemoveAll(cachePath)
	os.Setenv("GOCACHE", cachePath)
	os.Setenv("GOMODCACHE", cachePath)
	os.Setenv("GOPATH", cachePath)

	listArgs := goenv.goCmd("list")
	if len(build.Default.BuildTags) > 0 {
		listArgs = append(listArgs, "-tags", strings.Join(build.Default.BuildTags, ","))
	}
	listArgs = append(listArgs, "-json", "builtin", "std", "runtime/cgo")

	jsonFile, err := os.Create(*out)
	if err != nil {
		return err
	}
	defer jsonFile.Close()

	jsonData := &bytes.Buffer{}
	if err := goenv.runCommandToFile(jsonData, listArgs); err != nil {
		return err
	}

	encoder := json.NewEncoder(jsonFile)
	decoder := json.NewDecoder(jsonData)
	for decoder.More() {
		var pkg *goListPackage
		if err := decoder.Decode(&pkg); err != nil {
			return err
		}
		if err := encoder.Encode(flatPackageForStd(execRoot, pkg)); err != nil {
			return err
		}
	}

	return nil
}
