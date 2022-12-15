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

// link combines the results of a compile step using "go tool link". It is invoked by the
// Go rules as an action.
package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

func link(args []string) error {
	// Parse arguments.
	args, _, err := expandParamsFiles(args)
	if err != nil {
		return err
	}
	builderArgs, toolArgs := splitArgs(args)
	stamps := multiFlag{}
	xdefs := multiFlag{}
	experiments := multiFlag{}
	archives := archiveMultiFlag{}
	flags := flag.NewFlagSet("link", flag.ExitOnError)
	goenv := envFlags(flags)
	main := flags.String("main", "", "Path to the main archive.")
	packagePath := flags.String("p", "", "Package path of the main archive.")
	outFile := flags.String("o", "", "Path to output file.")
	flags.Var(&archives, "arc", "Label, package path, and file name of a dependency, separated by '='")
	packageList := flags.String("package_list", "", "The file containing the list of standard library packages")
	buildmode := flags.String("buildmode", "", "Build mode used.")
	flags.Var(&xdefs, "X", "A string variable to replace in the linked binary (repeated).")
	flags.Var(&stamps, "stamp", "The name of a file with stamping values.")
	flags.Var(&experiments, "experiment", "Go experiments to enable via GOEXPERIMENT")
	conflictErrMsg := flags.String("conflict_err", "", "Error message about conflicts to report if there's a link error.")
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}

	if *conflictErrMsg != "" {
		return errors.New(*conflictErrMsg)
	}

	// On Windows, take the absolute path of the output file and main file.
	// This is needed on Windows because the relative path is frequently too long.
	// os.Open on Windows converts absolute paths to some other path format with
	// longer length limits. Absolute paths do not work on macOS for .dylib
	// outputs because they get baked in as the "install path".
	if runtime.GOOS != "darwin" && runtime.GOOS != "ios" {
		*outFile = abs(*outFile)
	}
	*main = abs(*main)

	// If we were given any stamp value files, read and parse them
	stampMap := map[string]string{}
	for _, stampfile := range stamps {
		stampbuf, err := ioutil.ReadFile(stampfile)
		if err != nil {
			return fmt.Errorf("Failed reading stamp file %s: %v", stampfile, err)
		}
		scanner := bufio.NewScanner(bytes.NewReader(stampbuf))
		for scanner.Scan() {
			line := strings.SplitN(scanner.Text(), " ", 2)
			switch len(line) {
			case 0:
				// Nothing to do here
			case 1:
				// Map to the empty string
				stampMap[line[0]] = ""
			case 2:
				// Key and value
				stampMap[line[0]] = line[1]
			}
		}
	}

	// Build an importcfg file.
	importcfgName, err := buildImportcfgFileForLink(archives, *packageList, goenv.installSuffix, filepath.Dir(*outFile))
	if err != nil {
		return err
	}
	if !goenv.shouldPreserveWorkDir {
		defer os.Remove(importcfgName)
	}

	// generate any additional link options we need
	goargs := goenv.goTool("link")
	goargs = append(goargs, "-importcfg", importcfgName)

	parseXdef := func(xdef string) (pkg, name, value string, err error) {
		eq := strings.IndexByte(xdef, '=')
		if eq < 0 {
			return "", "", "", fmt.Errorf("-X flag does not contain '=': %s", xdef)
		}
		dot := strings.LastIndexByte(xdef[:eq], '.')
		if dot < 0 {
			return "", "", "", fmt.Errorf("-X flag does not contain '.': %s", xdef)
		}
		pkg, name, value = xdef[:dot], xdef[dot+1:eq], xdef[eq+1:]
		if pkg == *packagePath {
			pkg = "main"
		}
		return pkg, name, value, nil
	}
	for _, xdef := range xdefs {
		pkg, name, value, err := parseXdef(xdef)
		if err != nil {
			return err
		}
		var missingKey bool
		value = regexp.MustCompile(`\{.+?\}`).ReplaceAllStringFunc(value, func(key string) string {
			if value, ok := stampMap[key[1:len(key)-1]]; ok {
				return value
			}
			missingKey = true
			return key
		})
		if !missingKey {
			goargs = append(goargs, "-X", fmt.Sprintf("%s.%s=%s", pkg, name, value))
		}
	}

	if *buildmode != "" {
		goargs = append(goargs, "-buildmode", *buildmode)
	}
	goargs = append(goargs, "-o", *outFile)

	if len(experiments) > 0 {
		os.Setenv("GOEXPERIMENT", strings.Join(experiments, ","))
	}

	// add in the unprocess pass through options
	goargs = append(goargs, toolArgs...)
	goargs = append(goargs, *main)
	if err := goenv.runCommand(goargs); err != nil {
		return err
	}

	if *buildmode == "c-archive" {
		if err := stripArMetadata(*outFile); err != nil {
			return fmt.Errorf("error stripping archive metadata: %v", err)
		}
	}

	return nil
}
