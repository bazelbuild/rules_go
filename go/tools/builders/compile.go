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
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func compile(args []string) error {
	// Parse arguments.
	args, err := expandParamsFiles(args)
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
	outExport := flags.String("x", "", "The output archive file to write export data and nogo facts")
	output := flags.String("o", "", "The output archive file to write compiled code")
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
	all, err := filterAndSplitFiles(unfiltered)
	if err != nil {
		return err
	}
	goFiles, sFiles, hFiles := all.goSrcs, all.sSrcs, all.hSrcs
	if len(all.cSrcs) > 0 {
		return fmt.Errorf("unexpected C file: %s", all.cSrcs[0].filename)
	}
	if len(all.cxxSrcs) > 0 {
		return fmt.Errorf("unexpected C++ file: %s", all.cxxSrcs[0].filename)
	}
	switch *testfilter {
	case "off":
	case "only":
		testFiles := make([]fileInfo, 0, len(goFiles))
		for _, f := range goFiles {
			if strings.HasSuffix(f.pkg, "_test") {
				testFiles = append(testFiles, f)
			}
		}
		goFiles = testFiles
	case "exclude":
		libFiles := make([]fileInfo, 0, len(goFiles))
		for _, f := range goFiles {
			if !strings.HasSuffix(f.pkg, "_test") {
				libFiles = append(libFiles, f)
			}
		}
		goFiles = libFiles
	default:
		return fmt.Errorf("invalid test filter %q", *testfilter)
	}
	if len(goFiles) == 0 {
		// We need to run the compiler to create a valid archive, even if there's
		// nothing in it. GoPack will complain if we try to add assembly or cgo
		// objects.
		emptyPath := filepath.Join(filepath.Dir(*output), "_empty.go")
		if err := ioutil.WriteFile(emptyPath, []byte("package empty\n"), 0666); err != nil {
			return err
		}
		goFiles = append(goFiles, fileInfo{filename: emptyPath, pkg: "empty"})
	}

	if *packagePath == "" {
		*packagePath = goFiles[0].pkg
	}

	// Check that the filtered sources don't import anything outside of
	// the standard library and the direct dependencies.
	imports, err := checkImports(goFiles, archives, *packageList)
	if err != nil {
		return err
	}

	// Build an importcfg file for the compiler.
	importcfgName, err := buildImportcfgFileForCompile(imports, goenv.installSuffix, filepath.Dir(*output))
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

	// tempdir to store nogo facts and pkgdef for packaging later
	xTempDir, err := ioutil.TempDir(filepath.Dir(*outExport), "x_files")
	if err != nil {
		return err
	}
	defer os.RemoveAll(xTempDir)
	// Run nogo concurrently.
	var nogoOutput bytes.Buffer
	nogoStatus := nogoNotRun
	outFact := filepath.Join(xTempDir, nogoFact)
	if *nogo != "" {
		var nogoargs []string
		nogoargs = append(nogoargs, "-p", *packagePath)
		nogoargs = append(nogoargs, "-importcfg", importcfgName)
		for _, arc := range archives {
			nogoargs = append(nogoargs, "-fact", fmt.Sprintf("%s=%s", arc.importPath, arc.file))
		}
		nogoargs = append(nogoargs, "-x", outFact)
		nogoargs = append(nogoargs, filenames...)
		nogoCmd := exec.Command(*nogo, nogoargs...)
		nogoCmd.Stdout, nogoCmd.Stderr = &nogoOutput, &nogoOutput
		if err := nogoCmd.Run(); err != nil {
			if _, ok := err.(*exec.ExitError); ok {
				// Only fail the build if nogo runs and finds errors in source code.
				nogoStatus = nogoFailed
			} else {
				// All errors related to running nogo will merely be printed.
				nogoOutput.WriteString(fmt.Sprintf("error running nogo: %v\n", err))
				nogoStatus = nogoError
			}
		} else {
			nogoStatus = nogoSucceeded
		}
	}
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("error running compiler: %v", err)
	}

	// Only print the output of nogo if compilation succeeds.
	if nogoStatus == nogoFailed {
		return fmt.Errorf("%s", nogoOutput.String())
	}
	if nogoOutput.Len() != 0 {
		fmt.Fprintln(os.Stderr, nogoOutput.String())
	}

	// Extract the export data file and pack it in an .x archive together with the
	// nogo facts file (if there is one). This allows compile actions to depend
	// on .x files only, so we don't need to recompile a package when one of its
	// imports changes in a way that doesn't affect export data.
	// TODO(golang/go#33820): Ideally, we would use -linkobj to tell the compiler
	// to create separate .a and .x files for compiled code and export data, then
	// copy the nogo facts into the .x file. Unfortunately, when building a plugin,
	// the linker needs export data in the .a file. To work around this, we copy
	// the export data into the .x file ourselves.
	if err = extractFileFromArchive(*output, xTempDir, pkgDef); err != nil {
		return err
	}
	pkgDefPath := filepath.Join(xTempDir, pkgDef)
	if nogoStatus == nogoSucceeded {
		return appendFiles(goenv, *outExport, []string{pkgDefPath, outFact})
	}
	return appendFiles(goenv, *outExport, []string{pkgDefPath})
}

type nogoResult int

const (
	nogoNotRun nogoResult = iota
	nogoError
	nogoFailed
	nogoSucceeded
)
