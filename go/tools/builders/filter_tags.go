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

// tags takes a list of go source files and does tag filtering on them.
package main

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
	"strings"
)

func run(args []string) error {
	// Prepare our flags
	flags := flag.NewFlagSet("filter_tags", flag.ExitOnError)
	cgo := flags.Bool("cgo", false, "Sets whether cgo-using files are allowed to pass the filter.")
	quiet := flags.Bool("quiet", false, "Don't print filenames. Return code will be 0 if any files pass the filter.")
	tags := flags.String("tags", "", "Only pass through files that match these tags.")
	output := flags.String("output", "", "If set, write the matching files to this file, instead of stdout.")
	if err := flags.Parse(args); err != nil {
		return err
	}
	// filter our input file list
	bctx := build.Default
	bctx.CgoEnabled = *cgo
	bctx.BuildTags = strings.Split(*tags, ",")
	filenames, err := filterFiles(bctx, flags.Args())
	if err != nil {
		return err
	}
	// if we are in quite mode, just vary our exit condition based on the results
	if *quiet {
		if len(filenames) == 0 {
			os.Exit(1)
		}
		return nil
	}
	// print the outputs if we need not
	to := os.Stdout
	if *output != "" {
		f, err := os.Create(*output)
		if err != nil {
			return err
		}
		defer f.Close()
		to = f
	}
	for _, filename := range filenames {
		fmt.Fprintln(to, filename)
	}

	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
