/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var (
	cgo   = flag.Bool("cgo", false, "Sets whether cgo-using files are allowed to pass the filter.")
	quiet = flag.Bool("quiet", false, "Don't print filenames. Return code will be 0 if any files pass the filter.")
	tags  = flag.String("tags", "", "Only pass through files that match these tags.")
	run   = flag.Bool("run", false, "Run mode, filter a command line and then run it.")

	absMarker    = "≡"
	filterMarker = ""
)

// Returns an array of strings containing only the filenames that should build
// according to the Context given.
func filterFilenames(bctx build.Context, inputs []string) ([]string, error) {
	outputs := []string{}

	for _, filename := range inputs {
		fullPath, err := filepath.Abs(filename)
		if err != nil {
			return nil, err
		}
		dir, base := filepath.Split(fullPath)

		matches, err := bctx.MatchFile(dir, base)
		if err != nil {
			return nil, err
		}

		if matches {
			outputs = append(outputs, filename)
		}
	}
	return outputs, nil
}

// Returns an array of strings containing only the filenames that should build
// according to the Context given.
func runCommand(bctx build.Context, inputs []string) error {
	if len(inputs) <= 0 {
		return fmt.Errorf("filter_tags in run mode but with no command to run")
	}
	executable := inputs[0]
	args := []string{}
	unfiltered := 0
	filtered := 0
	for _, in := range inputs[1:] {
		if strings.HasPrefix(in, absMarker) {
			in, _ = filepath.Abs(in[len(absMarker):])
		}
		if !strings.HasPrefix(in, filterMarker) {
			// not a filter candidate
			args = append(args, in)
			continue
		}
		filename := in[len(filterMarker):]
		fullPath, err := filepath.Abs(filename)
		if _, err := os.Stat(filename); err != nil {
			// not a valid file, don't filter
			args = append(args, filename)
			continue
		}
		dir, base := filepath.Split(fullPath)
		matches, err := bctx.MatchFile(dir, base)
		if err != nil {
			//match test failure, return it
			return err
		}
		if !matches {
			// file should be filtered...
			filtered++
			continue
		}
		// not a match, add it
		args = append(args, filename)
		unfiltered++
	}
	// args should now be filtered
	// if all possible filter candidates were removed, then don't run the command
	if filtered > 0 && unfiltered == 0 {
		os.Exit(1)
	}
	// if we get here, we want to run the command itself
	cmd := exec.Command(executable, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	flag.Parse()

	bctx := build.Default
	bctx.BuildTags = strings.Split(*tags, ",")
	bctx.CgoEnabled = *cgo

	if *run {
		if err := runCommand(bctx, flag.Args()); err != nil {
			log.Fatalf("filter_tags error: %v\n", err)
		}
		return
	}

	filenames, err := filterFilenames(bctx, flag.Args())
	if err != nil {
		log.Fatalf("filter_tags error: %v\n", err)
	}

	if !*quiet {
		for _, filename := range filenames {
			fmt.Println(filename)
		}
	}
	if len(filenames) == 0 {
		os.Exit(1)
	}
}
