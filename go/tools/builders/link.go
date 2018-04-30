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
	"log"
	"os"
	"path/filepath"
	"strings"
)

func run(args []string) error {
	// Parse arguments.
	builderArgs, toolArgs := splitArgs(args)
	xstamps := multiFlag{}
	stamps := multiFlag{}
	deps := multiFlag{}
	flags := flag.NewFlagSet("link", flag.ExitOnError)
	goenv := envFlags(flags)
	main := flags.String("main", "", "Path to the main archive.")
	outFile := flags.String("o", "", "Path to output file.")
	buildmode := flags.String("buildmode", "", "Build mode used.")
	flags.Var(&stamps, "stamp", "The name of a file with stamping values.")
	flags.Var(&xstamps, "Xstamp", "A link xdef that may need stamping.")
	flags.Var(&deps, "dep", "A dependency formatted as label=pkgpath=pkgfile")
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}

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

	// generate any additional link options we need
	goargs := []string{"tool", "link"}
	depsSeen := make(map[string]string)
	for _, d := range deps {
		parts := strings.Split(d, "=")
		if len(parts) != 3 {
			return fmt.Errorf("Invalid dep %q: should be label=pkgpath=pkgfile", d)
		}
		label, pkgPath, pkgFile := parts[0], parts[1], parts[2]
		if conflictLabel, ok := depsSeen[pkgPath]; ok {
			// TODO(#1327): link.bzl should report this as a failure after 0.11.0.
			// At this point, we'll prepare an importcfg file and remove logic here.
			log.Printf(`warning: package %q is provided by more than one rule:
    %s
    %s
Set "importmap" to different paths in each library.
This will be an error in the future.`, pkgPath, label, conflictLabel)
			continue
		}
		depsSeen[pkgPath] = label

		pkgSuffix := string(os.PathSeparator) + filepath.FromSlash(pkgPath) + ".a"
		if !strings.HasSuffix(pkgFile, pkgSuffix) {
			return fmt.Errorf("package file name %q must have searchable suffix %q", pkgFile, pkgSuffix)
		}
		searchPath := pkgFile[:len(pkgFile)-len(pkgSuffix)]
		goargs = append(goargs, "-L", searchPath)
	}
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
	if err := goenv.runGoCommand(goargs); err != nil {
		return err
	}

	if *buildmode == "c-archive" {
		if err := stripArMetadata(*outFile); err != nil {
			return fmt.Errorf("error stripping archive metadata: %v", err)
		}
	}

	return nil
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("GoLink: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
