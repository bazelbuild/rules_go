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
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
)

type archive struct {
	label, pkgPath, file string
}

func run(args []string) error {
	// Parse arguments.
	args, err := readParamsFiles(args)
	if err != nil {
		return err
	}
	builderArgs, toolArgs := splitArgs(args)
	xstamps := multiFlag{}
	stamps := multiFlag{}
	archives := archiveMultiFlag{}
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

	// On Windows, take the absolute path of the output file.
	// This is needed on Windows because the relative path is frequently too long.
	// os.Open on Windows converts absolute paths to some other path format with
	// longer length limits. Absolute paths do not work on macOS for .dylib
	// outputs because they get baked in as the "install path".
	if goos, ok := os.LookupEnv("GOOS"); !ok {
		return fmt.Errorf("GOOS not set")
	} else if goos == "windows" {
		*outFile = abs(*outFile)
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

	// Build an importcfg file.
	importcfgName, err := buildImportcfgFile(archives, *packageList, goenv.installSuffix, filepath.Dir(*outFile))
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

func buildImportcfgFile(archives []archive, packageList, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	prefix := abs(filepath.Join(goroot, "pkg", installSuffix))
	packageListFile, err := os.Open(packageList)
	if err != nil {
		return "", err
	}
	defer packageListFile.Close()
	scanner := bufio.NewScanner(packageListFile)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		fmt.Fprintf(buf, "packagefile %s=%s.a\n", line, filepath.Join(prefix, filepath.FromSlash(line)))
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	depsSeen := map[string]string{}
	for _, arc := range archives {
		if conflictLabel, ok := depsSeen[arc.pkgPath]; ok {
			// TODO(#1327): link.bzl should report this as a failure after 0.11.0.
			// At this point, we'll prepare an importcfg file and remove logic here.
			log.Printf(`warning: package %q is provided by more than one rule:
    %s
    %s
Set "importmap" to different paths in each library.
This will be an error in the future.`, arc.pkgPath, arc.label, conflictLabel)
			continue
		}
		depsSeen[arc.pkgPath] = arc.label
		fmt.Fprintf(buf, "packagefile %s=%s\n", arc.pkgPath, arc.file)
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
	return fmt.Sprint(m)
}

func (m *archiveMultiFlag) Set(v string) error {
	parts := strings.Split(v, "=")
	if len(parts) != 3 {
		return fmt.Errorf("badly formed -arc flag: %s", v)
	}
	*m = append(*m, archive{
		label:   parts[0],
		pkgPath: parts[1],
		file:    abs(parts[2]),
	})
	return nil
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("GoLink: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
