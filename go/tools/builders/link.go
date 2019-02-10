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
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

func link(args []string) error {
	// Parse arguments.
	args, err := readParamsFiles(args)
	if err != nil {
		return err
	}
	builderArgs, toolArgs := splitArgs(args)
	xstamps := multiFlag{}
	stamps := multiFlag{}
	archives := linkArchiveMultiFlag{}
	flags := flag.NewFlagSet("link", flag.ExitOnError)
	goenv := envFlags(flags)
	main := flags.String("main", "", "Path to the main archive.")
	outFile := flags.String("o", "", "Path to output file.")
	flags.Var(&archives, "arc", "Label, package path, and file name of a dependency, separated by '='")
	packageList := flags.String("package_list", "", "The file containing the list of standard library packages")
	buildmode := flags.String("buildmode", "", "Build mode used.")
	flags.Var(&stamps, "stamp", "The name of a file with stamping values.")
	flags.Var(&xstamps, "Xstamp", "A link xdef that may need stamping.")
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}

	// On Windows, take the absolute path of the output file and main file.
	// This is needed on Windows because the relative path is frequently too long.
	// os.Open on Windows converts absolute paths to some other path format with
	// longer length limits. Absolute paths do not work on macOS for .dylib
	// outputs because they get baked in as the "install path".
	if runtime.GOOS != "darwin" {
		*outFile = abs(*outFile)
	}
	*main = abs(*main)

	// If we were given any stamp value files, read and parse them
	stampmap := map[string]string{}
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
				stampmap[line[0]] = ""
			case 2:
				// Key and value
				stampmap[line[0]] = line[1]
			}
		}
	}

	// Build an importcfg file.
	importcfgName, err := buildImportcfgFileForLink(archives, *packageList, goenv.installSuffix, filepath.Dir(*outFile))
	if err != nil {
		return err
	}
	defer os.Remove(importcfgName)

	// generate any additional link options we need
	goargs := goenv.goTool("link")
	goargs = append(goargs, "-importcfg", importcfgName)
	for _, xdef := range xstamps {
		split := strings.SplitN(xdef, "=", 2)
		if len(split) != 2 {
			continue
		}
		name := split[0]
		key := split[1]
		if value, found := stampmap[key]; found {
			goargs = append(goargs, "-X", fmt.Sprintf("%s=%s", name, value))
		}
	}

	if *buildmode != "" {
		goargs = append(goargs, "-buildmode", *buildmode)
	}
	goargs = append(goargs, "-o", *outFile)

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
