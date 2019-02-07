// Copyright 2017 The Bazel Authors. All rights reserved.
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

// compile compiles .go files with "go tool compile". It is invoked by the
// Go rules as an action.
package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"go/build"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

type archive struct {
	importPath, importMap, file, xFile string
}

func run(args []string) error {
	// Parse arguments.
	args, err := readParamsFiles(args)
	if err != nil {
		return err
	}
	builderArgs, toolArgs := splitArgs(args)
	flags := flag.NewFlagSet("GoCompile", flag.ExitOnError)
	unfiltered := multiFlag{}
	archives := archiveMultiFlag{}
	goenv := envFlags(flags)
	packagePath := flags.String("p", "", "The package path (importmap) of the package being compiled")
	flags.Var(&unfiltered, "src", "A source file to be filtered and compiled")
	flags.Var(&archives, "arc", "Import path, package path, and file name of a direct dependency, separated by '='")
	nogo := flags.String("nogo", "", "The nogo binary")
	outExport := flags.String("x", "", "Path to nogo that should be written")
	output := flags.String("o", "", "The output object file to write")
	asmhdr := flags.String("asmhdr", "", "Path to assembly header file to write")
	packageList := flags.String("package_list", "", "The file containing the list of standard library packages")
	testfilter := flags.String("testfilter", "off", "Controls test package filtering")
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	*output = abs(*output)
	if *asmhdr != "" {
		*asmhdr = abs(*asmhdr)
	}

	// Filter sources using build constraints.
	var matcher func(f *goMetadata) bool
	switch *testfilter {
	case "off":
		matcher = func(f *goMetadata) bool {
			return true
		}
	case "only":
		matcher = func(f *goMetadata) bool {
			return strings.HasSuffix(f.filename, ".go") && strings.HasSuffix(f.pkg, "_test")
		}
	case "exclude":
		matcher = func(f *goMetadata) bool {
			return !strings.HasSuffix(f.filename, ".go") || !strings.HasSuffix(f.pkg, "_test")
		}
	default:
		return fmt.Errorf("Invalid test filter %q", *testfilter)
	}
	// apply build constraints to the source list
	all, err := readFiles(build.Default, unfiltered)
	if err != nil {
		return err
	}
	var goFiles, sFiles, hFiles []*goMetadata
	for _, f := range all {
		if matcher(f) {
			switch path.Ext(f.filename) {
			case ".go":
				goFiles = append(goFiles, f)
			case ".s":
				sFiles = append(sFiles, f)
			case ".h":
				hFiles = append(hFiles, f)
			default:
				return fmt.Errorf("unknown file extension: %s", f.filename)
			}
		}
	}
	if len(goFiles) == 0 {
		// We need to run the compiler to create a valid archive, even if there's
		// nothing in it. GoPack will complain if we try to add assembly or cgo
		// objects.
		emptyPath := filepath.Join(filepath.Dir(*output), "_empty.go")
		if err := ioutil.WriteFile(emptyPath, []byte("package empty\n"), 0666); err != nil {
			return err
		}
		goFiles = append(goFiles, &goMetadata{filename: emptyPath, pkg: "empty"})
	}

	if *packagePath == "" {
		*packagePath = goFiles[0].pkg
	}

	// Check that the filtered sources don't import anything outside of
	// the standard library and the direct dependencies.
	_, stdImports, err := checkDirectDeps(goFiles, archives, *packageList)
	if err != nil {
		return err
	}

	// Build an importcfg file for the compiler.
	importcfgName, err := buildImportcfgFile(archives, stdImports, goenv.installSuffix, filepath.Dir(*output))
	if err != nil {
		return err
	}
	defer os.Remove(importcfgName)

	// If there are assembly files, and this is go1.12+, generate symbol ABIs.
	symabisName, err := buildSymabisFile(goenv, sFiles, hFiles, *asmhdr)
	if symabisName != "" {
		defer os.Remove(symabisName)
	}
	if err != nil {
		return err
	}

	// Compile the filtered files.
	goargs := goenv.goTool("compile")
	goargs = append(goargs, "-p", *packagePath)
	goargs = append(goargs, "-importcfg", importcfgName)
	goargs = append(goargs, "-pack", "-o", *output)
	if symabisName != "" {
		goargs = append(goargs, "-symabis", symabisName)
	}
	if *asmhdr != "" {
		goargs = append(goargs, "-asmhdr", *asmhdr)
	}
	goargs = append(goargs, toolArgs...)
	goargs = append(goargs, "--")
	filenames := make([]string, 0, len(goFiles))
	for _, f := range goFiles {
		filenames = append(filenames, f.filename)
	}
	goargs = append(goargs, filenames...)
	absArgs(goargs, []string{"-I", "-o", "-trimpath", "-importcfg"})
	cmd := exec.Command(goargs[0], goargs[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("error starting compiler: %v", err)
	}

	// Run nogo concurrently.
	var nogoOutput bytes.Buffer
	nogoFailed := false
	if *nogo != "" {
		var nogoargs []string
		nogoargs = append(nogoargs, "-p", *packagePath)
		nogoargs = append(nogoargs, "-importcfg", importcfgName)
		for _, imp := range stdImports {
			nogoargs = append(nogoargs, "-stdimport", imp)
		}
		for _, arc := range archives {
			if arc.xFile != "" {
				nogoargs = append(nogoargs, "-fact", fmt.Sprintf("%s=%s", arc.importPath, arc.xFile))
			}
		}
		nogoargs = append(nogoargs, "-x", *outExport)
		nogoargs = append(nogoargs, filenames...)
		nogoCmd := exec.Command(*nogo, nogoargs...)
		nogoCmd.Stdout, nogoCmd.Stderr = &nogoOutput, &nogoOutput
		if err := nogoCmd.Run(); err != nil {
			if _, ok := err.(*exec.ExitError); ok {
				// Only fail the build if nogo runs and finds errors in source code.
				nogoFailed = true
			} else {
				// All errors related to running nogo will merely be printed.
				nogoOutput.WriteString(fmt.Sprintf("error running nogo: %v\n", err))
			}
		}
	}
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("error running compiler: %v", err)
	}
	// Only print the output of nogo if compilation succeeds.
	if nogoFailed {
		return fmt.Errorf("%s", nogoOutput.String())
	}
	if nogoOutput.Len() != 0 {
		fmt.Fprintln(os.Stderr, nogoOutput.String())
	}
	return nil
}

func main() {
	log.SetFlags(0) // no timestamp
	log.SetPrefix("GoCompile: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

// TODO(#1891): consolidate this logic when compile and asm are in the
// same binary.
func buildSymabisFile(goenv *env, sFiles, hFiles []*goMetadata, asmhdr string) (string, error) {
	if len(sFiles) == 0 {
		return "", nil
	}

	// Check version. The symabis file is only required and can only be built
	// starting at go1.12.
	version := runtime.Version()
	if strings.HasPrefix(version, "go1.") {
		minor := version[len("go1."):]
		if i := strings.IndexByte(minor, '.'); i >= 0 {
			minor = minor[:i]
		}
		n, err := strconv.Atoi(minor)
		if err == nil && n <= 11 {
			return "", nil
		}
		// Fall through if the version can't be parsed. It's probably a newer
		// development version.
	}

	// Create an empty go_asm.h file. The compiler will write this later, but
	// we need one to exist now.
	asmhdrFile, err := os.Create(asmhdr)
	if err != nil {
		return "", err
	}
	if err := asmhdrFile.Close(); err != nil {
		return "", err
	}
	asmhdrDir := filepath.Dir(asmhdr)

	// Create a temporary output file. The caller is responsible for deleting it.
	var symabisName string
	symabisFile, err := ioutil.TempFile("", "symabis")
	if err != nil {
		return "", err
	}
	symabisName = symabisFile.Name()
	symabisFile.Close()

	// Run the assembler.
	wd, err := os.Getwd()
	if err != nil {
		return symabisName, err
	}
	asmargs := goenv.goTool("asm")
	asmargs = append(asmargs, "-trimpath", wd)
	asmargs = append(asmargs, "-I", wd)
	asmargs = append(asmargs, "-I", filepath.Join(os.Getenv("GOROOT"), "pkg", "include"))
	asmargs = append(asmargs, "-I", asmhdrDir)
	seenHdrDirs := map[string]bool{wd: true, asmhdrDir: true}
	for _, hFile := range hFiles {
		hdrDir := filepath.Dir(abs(hFile.filename))
		if !seenHdrDirs[hdrDir] {
			asmargs = append(asmargs, "-I", hdrDir)
			seenHdrDirs[hdrDir] = true
		}
	}
	// TODO(#1894): define GOOS_goos, GOARCH_goarch, both here and in the
	// GoAsm action.
	asmargs = append(asmargs, "-gensymabis", "-o", symabisName, "--")
	for _, sFile := range sFiles {
		asmargs = append(asmargs, sFile.filename)
	}

	err = goenv.runCommand(asmargs)
	return symabisName, err
}

func checkDirectDeps(files []*goMetadata, archives []archive, packageList string) (depImports, stdImports []string, err error) {
	packagesTxt, err := ioutil.ReadFile(packageList)
	if err != nil {
		log.Fatal(err)
	}
	stdlibSet := map[string]bool{}
	for _, line := range strings.Split(string(packagesTxt), "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			stdlibSet[line] = true
		}
	}

	depSet := map[string]bool{}
	depList := make([]string, len(archives))
	for i, arc := range archives {
		depSet[arc.importPath] = true
		depList[i] = arc.importPath
	}

	importSet := map[string]bool{}

	derr := depsError{known: depList}
	for _, f := range files {
		for _, path := range f.imports {
			if path == "C" || isRelative(path) || importSet[path] {
				// TODO(#1645): Support local (relative) import paths. We don't emit
				// errors for them here, but they will probably break something else.
				continue
			}
			if stdlibSet[path] {
				stdImports = append(stdImports, path)
				continue
			}
			if depSet[path] {
				depImports = append(depImports, path)
				continue
			}
			derr.missing = append(derr.missing, missingDep{f.filename, path})
		}
	}
	if len(derr.missing) > 0 {
		return nil, nil, derr
	}
	return depImports, stdImports, nil
}

func buildImportcfgFile(archives []archive, stdImports []string, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	goroot = abs(goroot)
	// UGLY HACK: The vet tool called by compile program expects the vet.cfg file
	// passed to it to contain import information for package fmt. Since we use
	// importcfg to create vet.cfg, ensure that an entry for package fmt exists in
	// the former.
	stdImports = append(stdImports, "fmt")
	for _, imp := range stdImports {
		path := filepath.Join(goroot, "pkg", installSuffix, filepath.FromSlash(imp))
		fmt.Fprintf(buf, "packagefile %s=%s.a\n", imp, path)
	}
	for _, arc := range archives {
		if arc.importPath != arc.importMap {
			fmt.Fprintf(buf, "importmap %s=%s\n", arc.importPath, arc.importMap)
		}
		fmt.Fprintf(buf, "packagefile %s=%s\n", arc.importMap, arc.file)
	}
	f, err := ioutil.TempFile(dir, "importcfg")
	if err != nil {
		return "", err
	}
	filename := f.Name()
	if _, err := io.Copy(f, buf); err != nil {
		f.Close()
		os.Remove(filename)
		return "", err
	}
	if err := f.Close(); err != nil {
		os.Remove(filename)
		return "", err
	}
	return filename, nil
}

type archiveMultiFlag []archive

func (m *archiveMultiFlag) String() string {
	if m == nil || len(*m) == 0 {
		return ""
	}
	return fmt.Sprint(*m)
}

func (m *archiveMultiFlag) Set(v string) error {
	parts := strings.Split(v, "=")
	if len(parts) != 4 {
		return fmt.Errorf("badly formed -arc flag: %s", v)
	}
	a := archive{
		importPath: parts[0],
		importMap:  parts[1],
		file:       abs(parts[2]),
	}
	if parts[3] != "" {
		a.xFile = abs(parts[3])
	}
	*m = append(*m, a)
	return nil
}

type depsError struct {
	missing []missingDep
	known   []string
}

type missingDep struct {
	filename, imp string
}

var _ error = depsError{}

func (e depsError) Error() string {
	buf := bytes.NewBuffer(nil)
	fmt.Fprintf(buf, "missing strict dependencies:\n")
	for _, dep := range e.missing {
		fmt.Fprintf(buf, "\t%s: import of %q\n", dep.filename, dep.imp)
	}
	if len(e.known) == 0 {
		fmt.Fprintln(buf, "No dependencies were provided.")
	} else {
		fmt.Fprintln(buf, "Known dependencies are:")
		for _, imp := range e.known {
			fmt.Fprintf(buf, "\t%s\n", imp)
		}
	}
	fmt.Fprint(buf, "Check that imports in Go sources match importpath attributes in deps.")
	return buf.String()
}

func isRelative(path string) bool {
	return strings.HasPrefix(path, "./") || strings.HasPrefix(path, "../")
}
